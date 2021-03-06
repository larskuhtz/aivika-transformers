
-- |
-- Module     : Simulation.Aivika.Trans.Statistics.Accumulator
-- Copyright  : Copyright (c) 2009-2017, David Sorokin <david.sorokin@gmail.com>
-- License    : BSD3
-- Maintainer : David Sorokin <david.sorokin@gmail.com>
-- Stability  : experimental
-- Tested with: GHC 8.0.1
--
-- This small utility module allows accumulating the timing statistics based on 'Signalable' data
-- such as the queue size or the number of lost items in the queue.
--

module Simulation.Aivika.Trans.Statistics.Accumulator
       (-- * Timing Statistics Accumulator
        TimingStatsAccumulator,
        newTimingStatsAccumulator,
        timingStatsAccumulated) where

import Simulation.Aivika.Trans.Comp
import Simulation.Aivika.Trans.Simulation
import Simulation.Aivika.Trans.Dynamics
import Simulation.Aivika.Trans.Event
import Simulation.Aivika.Trans.Ref
import Simulation.Aivika.Trans.Statistics
import Simulation.Aivika.Trans.Signal
import Simulation.Aivika.Trans.DES

-- | Represents an accumulator for the timing statistics.
newtype TimingStatsAccumulator m a =
  TimingStatsAccumulator { timingStatsAccumulatedRef :: Ref m (TimingStats a) }

-- | Return the accumulated statistics.
timingStatsAccumulated :: MonadDES m => TimingStatsAccumulator m a -> Event m (TimingStats a)
{-# INLINABLE timingStatsAccumulated #-}
timingStatsAccumulated = readRef . timingStatsAccumulatedRef

-- | Start gathering the timing statistics from the current simulation time. 
newTimingStatsAccumulator :: (MonadDES m, TimingData a) => Signalable m a -> Event m (TimingStatsAccumulator m a)
{-# INLINABLE newTimingStatsAccumulator #-}
newTimingStatsAccumulator x =
  do t0 <- liftDynamics time
     a0 <- readSignalable x
     r  <- liftSimulation $ newRef (returnTimingStats t0 a0)
     handleSignal_ (signalableChanged x) $ \a ->
       do t <- liftDynamics time
          modifyRef r $ addTimingStats t a
     return TimingStatsAccumulator { timingStatsAccumulatedRef = r }
