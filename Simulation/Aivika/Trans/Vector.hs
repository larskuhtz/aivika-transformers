
{-# LANGUAGE TypeFamilies #-}

-- |
-- Module     : Simulation.Aivika.Trans.Vector
-- Copyright  : Copyright (c) 2009-2014, David Sorokin <david.sorokin@gmail.com>
-- License    : GPL
-- Maintainer : David Sorokin <david.sorokin@gmail.com>
-- Stability  : experimental
-- Tested with: GHC 7.8.3
--
-- It defines a prototype of mutable vectors.
--
module Simulation.Aivika.Trans.Vector
       (Vector,
        newVector, 
        copyVector,
        vectorCount, 
        appendVector, 
        readVector, 
        writeVector,
        vectorBinarySearch,
        vectorInsert,
        vectorDeleteAt,
        vectorIndex,
        freezeVector) where 

import Data.Array

import Control.Monad

import Simulation.Aivika.Trans.Session
import Simulation.Aivika.Trans.ProtoRef
import Simulation.Aivika.Trans.ProtoArray

-- | A prototype of mutable vector.
data Vector m a =
    Vector { vectorSession  :: Session m,
             vectorArrayRef :: ProtoRef m (ProtoArray m a),
             vectorCountRef :: ProtoRef m Int, 
             vectorCapacityRef :: ProtoRef m Int }

-- | Create a new vector within the specified simulation session.
newVector :: ProtoArrayMonad m => Session m -> m (Vector m a)
newVector session = 
  do array <- newProtoArray_ session 4
     arrayRef <- newProtoRef session array
     countRef <- newProtoRef session 0
     capacityRef <- newProtoRef session 4
     return Vector { vectorSession  = session,
                     vectorArrayRef = arrayRef,
                     vectorCountRef = countRef,
                     vectorCapacityRef = capacityRef }

-- | Copy the vector.
copyVector :: ProtoArrayMonad m => Vector m a -> m (Vector m a)
copyVector vector =
  do let session = vectorSession vector
     array <- readProtoRef (vectorArrayRef vector)
     count <- readProtoRef (vectorCountRef vector)
     array' <- newProtoArray_ session count
     arrayRef' <- newProtoRef session array'
     countRef' <- newProtoRef session count
     capacityRef' <- newProtoRef session count
     forM_ [0 .. count - 1] $ \i ->
       do x <- readProtoArray array i
          writeProtoArray array' i x
     return Vector { vectorSession  = session,
                     vectorArrayRef = arrayRef',
                     vectorCountRef = countRef',
                     vectorCapacityRef = capacityRef' }
       
-- | Ensure that the vector has the specified capacity.
vectorEnsureCapacity :: ProtoArrayMonad m => Vector m a -> Int -> m ()
vectorEnsureCapacity vector capacity =
  do capacity' <- readProtoRef (vectorCapacityRef vector)
     when (capacity' < capacity) $
       do array' <- readProtoRef (vectorArrayRef vector)
          count' <- readProtoRef (vectorCountRef vector)
          let capacity'' = max (2 * capacity') capacity
              session    = vectorSession vector
          array'' <- newProtoArray_ session capacity''
          forM_ [0 .. count' - 1] $ \i ->
            do x <- readProtoArray array' i
               writeProtoArray array'' i x
          writeProtoRef (vectorArrayRef vector) array''
          writeProtoRef (vectorCapacityRef vector) capacity''

-- | Return the element count.
vectorCount :: ProtoArrayMonad m => Vector m a -> m Int
vectorCount vector = readProtoRef (vectorCountRef vector)

-- | Add the specified element to the end of the vector.
appendVector :: ProtoArrayMonad m => Vector m a -> a -> m ()          
appendVector vector item =
  do count <- readProtoRef (vectorCountRef vector)
     vectorEnsureCapacity vector (count + 1)
     array <- readProtoRef (vectorArrayRef vector)
     writeProtoArray array count item
     writeProtoRef (vectorCountRef vector) (count + 1)

-- | Read a value from the vector, where indices are started from 0.
readVector :: ProtoArrayMonad m => Vector m a -> Int -> m a
readVector vector index =
  do array <- readProtoRef (vectorArrayRef vector)
     readProtoArray array index

-- | Set an array item at the specified index which is started from 0.
writeVector :: ProtoArrayMonad m => Vector m a -> Int -> a -> m ()
writeVector vector index item =
  do array <- readProtoRef (vectorArrayRef vector)
     writeProtoArray array index item

-- | Return the index of the specified element using binary search; otherwise, 
-- a negated insertion index minus one: 0 -> -0 - 1, ..., i -> -i - 1, ....
vectorBinarySearch :: (ProtoArrayMonad m, Ord a) => Vector m a -> a -> m Int
vectorBinarySearch vector item =
  do array <- readProtoRef (vectorArrayRef vector)
     count <- readProtoRef (vectorCountRef vector)
     vectorBinarySearch' array item 0 (count - 1)

-- | Return the index of the specified element using binary search
-- within the specified range; otherwise, a negated insertion index minus one.
vectorBinarySearchWithin :: (ProtoArrayMonad m, Ord a) => Vector m a -> a -> Int -> Int -> m Int
vectorBinarySearchWithin vector item left right =
  do array <- readProtoRef (vectorArrayRef vector)
     vectorBinarySearch' array item left right

-- | Return the elements of the vector in an immutable array.
freezeVector :: ProtoArrayMonad m => Vector m a -> m (Array Int a)
freezeVector vector =
  do array <- readProtoRef (vectorArrayRef vector)
     freezeProtoArray array

-- | Insert the element in the vector at the specified index.
vectorInsert :: ProtoArrayMonad m => Vector m a -> Int -> a -> m ()
vectorInsert vector index item =
  do count <- readProtoRef (vectorCountRef vector)
     when (index < 0) $
       error $
       "Index cannot be " ++
       "negative: vectorInsert."
     when (index > count) $
       error $
       "Index cannot be greater " ++
       "than the count: vectorInsert."
     vectorEnsureCapacity vector (count + 1)
     array <- readProtoRef (vectorArrayRef vector)
     forM_ [count, count - 1 .. index + 1] $ \i ->
       do x <- readProtoArray array (i - 1)
          writeProtoArray array i x
     writeProtoArray array index item
     writeProtoRef (vectorCountRef vector) (count + 1)

-- | Delete the element at the specified index.
vectorDeleteAt :: ProtoArrayMonad m => Vector m a -> Int -> m ()
vectorDeleteAt vector index =
  do count <- readProtoRef (vectorCountRef vector)
     when (index < 0) $
       error $
       "Index cannot be " ++
       "negative: vectorDeleteAt."
     when (index >= count) $
       error $
       "Index must be less " ++
       "than the count: vectorDeleteAt."
     array <- readProtoRef (vectorArrayRef vector)
     forM_ [index, index + 1 .. count - 2] $ \i ->
       do x <- readProtoArray array (i + 1)
          writeProtoArray array i x
     writeProtoArray array (count - 1) undefined
     writeProtoRef (vectorCountRef vector) (count - 1)

-- | Return the index of the item or -1.
vectorIndex :: (ProtoArrayMonad m, Eq a) => Vector m a -> a -> m Int
vectorIndex vector item =
  do count <- readProtoRef (vectorCountRef vector)
     array <- readProtoRef (vectorArrayRef vector)
     let loop index =
           if index >= count
           then return $ -1
           else do x <- readProtoArray array index
                   if item == x
                     then return index
                     else loop $ index + 1
     loop 0

vectorBinarySearch' :: (ProtoArrayMonad m, Ord a) => ProtoArray m a -> a -> Int -> Int -> m Int
vectorBinarySearch' array item left right =
  if left > right 
  then return $ - (right + 1) - 1
  else
    do let index = (left + right) `div` 2
       curr <- readProtoArray array index
       if item < curr 
         then vectorBinarySearch' array item left (index - 1)
         else if item == curr
              then return index
              else vectorBinarySearch' array item (index + 1) right
