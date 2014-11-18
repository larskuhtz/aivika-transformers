
{-# LANGUAGE TypeFamilies, MultiParamTypeClasses, FlexibleInstances, FlexibleContexts, FunctionalDependencies, UndecidableInstances #-}

-- |
-- Module     : Simulation.Aivika.Trans.QueueStrategy.IO
-- Copyright  : Copyright (c) 2009-2014, David Sorokin <david.sorokin@gmail.com>
-- License    : GPL-3
-- Maintainer : David Sorokin <david.sorokin@gmail.com>
-- Stability  : experimental
-- Tested with: GHC 7.8.3
--
-- This module defines some queue strategy instances.
--
module Simulation.Aivika.Trans.QueueStrategy.IO where

import Control.Monad.Trans

import Simulation.Aivika.Trans.DES
import Simulation.Aivika.Trans.Parameter
import Simulation.Aivika.Trans.Parameter.Random
import Simulation.Aivika.Trans.Simulation
import Simulation.Aivika.Trans.Event
import Simulation.Aivika.Trans.QueueStrategy
import Simulation.Aivika.Trans.Template

import qualified Simulation.Aivika.PriorityQueue as PQ
import qualified Simulation.Aivika.Vector as V

-- | A template-based implementation of the 'StaticPriorities' queue strategy.
instance (MonadDES m, TemplateIO m) => QueueStrategy m StaticPriorities where

  -- | A queue used by the 'StaticPriorities' strategy.
  newtype StrategyQueue m StaticPriorities a = StaticPriorityQueue (PQ.PriorityQueue a)

  newStrategyQueue s =
    fmap StaticPriorityQueue $
    liftIO $ PQ.newQueue

  strategyQueueNull (StaticPriorityQueue q) =
    liftIO $ PQ.queueNull q

-- | A template-based implementation of the 'StaticPriorities' queue strategy.
instance (QueueStrategy m StaticPriorities, TemplateIO m) => DequeueStrategy m StaticPriorities where

  strategyDequeue (StaticPriorityQueue q) =
    liftIO $
    do (_, i) <- PQ.queueFront q
       PQ.dequeue q
       return i

-- | A template-based implementation of the 'StaticPriorities' queue strategy.
instance (DequeueStrategy m StaticPriorities, TemplateIO m) => PriorityQueueStrategy m StaticPriorities Double where

  strategyEnqueueWithPriority (StaticPriorityQueue q) p i =
    liftIO $ PQ.enqueue q p i

-- | A template-based implementation of the 'SIRO' queue strategy.
instance (MonadDES m, TemplateIO m) => QueueStrategy m SIRO where

  -- | A queue used by the 'SIRO' strategy.
  newtype StrategyQueue m SIRO a = SIROQueue (V.Vector a)
  
  newStrategyQueue s =
    fmap SIROQueue $
    liftIO $ V.newVector

  strategyQueueNull (SIROQueue q) =
    liftIO $
    do n <- V.vectorCount q
       return (n == 0)

-- | A template-based implementation of the 'SIRO' queue strategy.
instance (QueueStrategy m SIRO, TemplateIO m) => DequeueStrategy m SIRO where

  strategyDequeue (SIROQueue q) =
    do n <- liftIO $ V.vectorCount q
       i <- liftParameter $ randomUniformInt 0 (n - 1)
       x <- liftIO $ V.readVector q i
       liftIO $ V.vectorDeleteAt q i
       return x

-- | A template-based implementation of the 'SIRO' queue strategy.
instance (DequeueStrategy m SIRO, TemplateIO m) => EnqueueStrategy m SIRO where

  strategyEnqueue (SIROQueue q) i =
    liftIO $ V.appendVector q i