
-- |
-- Module     : Simulation.Aivika.Trans.Dynamics
-- Copyright  : Copyright (c) 2009-2015, David Sorokin <david.sorokin@gmail.com>
-- License    : BSD3
-- Maintainer : David Sorokin <david.sorokin@gmail.com>
-- Stability  : experimental
-- Tested with: GHC 7.10.1
--
-- The module defines the 'DynamicsT' monad tranformer representing a time varying polymorphic function. 
--
module Simulation.Aivika.Trans.Dynamics
       (-- * Dynamics Monad
        Dynamics,
        DynamicsLift(..),
        runDynamicsInStartTime,
        runDynamicsInStopTime,
        runDynamicsInIntegTimes,
        runDynamicsInTime,
        runDynamicsInTimes,
        -- * Error Handling
        catchDynamics,
        finallyDynamics,
        throwDynamics,
        -- * Simulation Time
        time,
        isTimeInteg,
        integIteration,
        integPhase,
        -- * Debugging
        traceDynamics) where

import Simulation.Aivika.Trans.Internal.Dynamics
