
{-# LANGUAGE TypeFamilies, FlexibleInstances, UndecidableInstances #-}

-- |
-- Module     : Simulation.Aivika.IO.Event
-- Copyright  : Copyright (c) 2009-2017, David Sorokin <david.sorokin@gmail.com>
-- License    : BSD3
-- Maintainer : David Sorokin <david.sorokin@gmail.com>
-- Stability  : experimental
-- Tested with: GHC 8.0.1
--
-- The module defines an event queue, where the 'IO' monad is an instance of
-- 'EventQueueing' and 'EventIOQueueing'.
--
module Simulation.Aivika.IO.Event () where

import Control.Monad
import Control.Monad.Trans

import Data.IORef

import qualified Simulation.Aivika.PriorityQueue as PQ

import Simulation.Aivika.Trans.Ref.Base
import Simulation.Aivika.Trans.DES
import Simulation.Aivika.Trans.Comp
import Simulation.Aivika.Trans.Internal.Types
import Simulation.Aivika.Trans.Event

-- | An implementation of the 'EventQueueing' type class.
instance EventQueueing IO where
-- instance (Monad m, MonadIO m, MonadEventQueueTemplate m) => EventQueueing m where

  {-# SPECIALISE instance EventQueueing IO #-}

  data EventQueue IO =
    EventQueue { queuePQ :: PQ.PriorityQueue (Point IO -> IO ()),
                 -- ^ the underlying priority queue
                 queueBusy :: IORef Bool,
                 -- ^ whether the queue is currently processing events
                 queueTime :: IORef Double
                 -- ^ the actual time of the event queue
               }

  {-# INLINABLE newEventQueue #-}
  newEventQueue specs =
    liftIO $
    do f <- newIORef False
       t <- newIORef $ spcStartTime specs
       pq <- PQ.newQueue
       return EventQueue { queuePQ   = pq,
                           queueBusy = f,
                           queueTime = t }

  {-# INLINE enqueueEvent #-}
  enqueueEvent t (Event m) =
    Event $ \p ->
    let pq = queuePQ $ runEventQueue $ pointRun p
    in liftIO $ PQ.enqueue pq t m

  {-# INLINE runEventWith #-}
  runEventWith processing (Event e) =
    Dynamics $ \p ->
    do invokeDynamics p $ processEvents processing
       e p

  {-# INLINE eventQueueCount #-}
  eventQueueCount =
    Event $
    liftIO . PQ.queueCount . queuePQ . runEventQueue . pointRun

-- | Process the pending events.
processPendingEventsCore :: Bool -> Dynamics IO ()
-- processPendingEventsCore :: (MonadIO m, MonadEventQueueTemplate m) => Bool -> Dynamics m ()
{-# INLINE processPendingEventsCore #-}
processPendingEventsCore includingCurrentEvents = Dynamics r where
  r p =
    do let q = runEventQueue $ pointRun p
           f = queueBusy q
       f' <- liftIO $ readIORef f
       unless f' $
         do liftIO $ writeIORef f True
            call q p
            liftIO $ writeIORef f False
  call q p =
    do let pq = queuePQ q
           r  = pointRun p
       f <- liftIO $ PQ.queueNull pq
       unless f $
         do (t2, c2) <- liftIO $ PQ.queueFront pq
            let t = queueTime q
            t' <- liftIO $ readIORef t
            when (t2 < t') $ 
              error "The time value is too small: processPendingEventsCore"
            when ((t2 < pointTime p) ||
                  (includingCurrentEvents && (t2 == pointTime p))) $
              do liftIO $ writeIORef t t2
                 liftIO $ PQ.dequeue pq
                 let sc = pointSpecs p
                     t0 = spcStartTime sc
                     dt = spcDT sc
                     n2 = fromIntegral $ floor ((t2 - t0) / dt)
                 c2 $ p { pointTime = t2,
                          pointIteration = n2,
                          pointPhase = -1 }
                 call q p

-- | Process the pending events synchronously, i.e. without past.
processPendingEvents :: Bool -> Dynamics IO ()
-- processPendingEvents :: (MonadIO m, MonadEventQueueTemplate m) => Bool -> Dynamics m ()
{-# INLINE processPendingEvents #-}
processPendingEvents includingCurrentEvents = Dynamics r where
  r p =
    do let q = runEventQueue $ pointRun p
           t = queueTime q
       t' <- liftIO $ readIORef t
       if pointTime p < t'
         then error $
              "The current time is less than " ++
              "the time in the queue: processPendingEvents"
         else invokeDynamics p m
  m = processPendingEventsCore includingCurrentEvents

-- | A memoized value.
processEventsIncludingCurrent :: Dynamics IO ()
-- processEventsIncludingCurrent :: (MonadIO m, MonadEventQueueTemplate m) => Dynamics m ()
{-# INLINE processEventsIncludingCurrent #-}
processEventsIncludingCurrent = processPendingEvents True

-- | A memoized value.
processEventsIncludingEarlier :: Dynamics IO ()
-- processEventsIncludingEarlier :: (MonadIO m, MonadEventQueueTemplate m) => Dynamics m ()
{-# INLINE processEventsIncludingEarlier #-}
processEventsIncludingEarlier = processPendingEvents False

-- | A memoized value.
processEventsIncludingCurrentCore :: Dynamics IO ()
-- processEventsIncludingCurrentCore :: (MonadIO m, MonadEventQueueTemplate m) => Dynamics m ()
{-# INLINE processEventsIncludingCurrentCore #-}
processEventsIncludingCurrentCore = processPendingEventsCore True

-- | A memoized value.
processEventsIncludingEarlierCore :: Dynamics IO ()
-- processEventsIncludingEarlierCore :: (MonadIO m, MonadEventQueueTemplate m) => Dynamics m ()
{-# INLINE processEventsIncludingEarlierCore #-}
processEventsIncludingEarlierCore = processPendingEventsCore True

-- | Process the events.
processEvents :: EventProcessing -> Dynamics IO ()
-- processEvents :: (MonadIO m, MonadEventQueueTemplate m) => EventProcessing -> Dynamics m ()
{-# INLINABLE processEvents #-}
processEvents CurrentEvents = processEventsIncludingCurrent
processEvents EarlierEvents = processEventsIncludingEarlier
processEvents CurrentEventsOrFromPast = processEventsIncludingCurrentCore
processEvents EarlierEventsOrFromPast = processEventsIncludingEarlierCore

-- | An implementation of the 'EventIOQueueing' type class.
instance EventIOQueueing IO where
-- instance (Monad m, MonadIO m, MonadEventQueueTemplate m, MonadDES m) => EventIOQueueing m where

  {-# SPECIALISE instance EventIOQueueing IO #-}

  enqueueEventIO = enqueueEvent
