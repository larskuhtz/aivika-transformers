
{-# LANGUAGE FlexibleContexts #-}

-- |
-- Module     : Simulation.Aivika.Trans.Monad.DES
-- Copyright  : Copyright (c) 2009-2014, David Sorokin <david.sorokin@gmail.com>
-- License    : GPL
-- Maintainer : David Sorokin <david.sorokin@gmail.com>
-- Stability  : experimental
-- Tested with: GHC 7.8.3
--
-- It defines a type class of monads for Discrete Event Simulation (DES).
--
module Simulation.Aivika.Trans.Monad.DES (MonadDES) where

import Simulation.Aivika.Trans.Comp
import Simulation.Aivika.Trans.Ref.Base

-- | It defines a type class of monads for Discrete Event Simulation (DES).
class (MonadComp m, MonadRef m) => MonadDES m
