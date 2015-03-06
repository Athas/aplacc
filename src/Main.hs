module Main where

import Data.Maybe (fromMaybe)
import System.IO (IOMode(ReadMode), withFile, stdin, Handle, hGetContents)
import System.Environment
import System.Process (readProcessWithExitCode)
import System.Exit (ExitCode(..))

import APLAcc.TAIL.Parser (parseString)
import APLAcc.Conversion (convertProgram)
import APLAcc.SimpleAcc.ToHaskell (toHs, OutputOpts(..), defaultOpts)


main :: IO ()
main =
  do args <- getArgs
     case parseArgs args defaultOpts of
       (["-"], opts) -> compileFile "stdin" opts stdin
       ([f],   opts) -> withFile f ReadMode (compileFile f opts)
       _             -> putStrLn "usage: aplacc [-c|--cuda] <file>"
  where parseArgs ("-c"     : rest) opts = parseArgs rest (opts { toCUDA = True })
        parseArgs ("--cuda" : rest) opts = parseArgs rest (opts { toCUDA = True })
        parseArgs ("-t"     : rest) opts = parseArgs rest (opts { tailInput = True })
        parseArgs ("--tail" : rest) opts = parseArgs rest (opts { tailInput = True })
        parseArgs ("--run"  : rest) opts = parseArgs rest (opts { runProgram = True })
        parseArgs (x : rest) opts        = let (as, opts') = parseArgs rest opts
                                           in (x:as, opts')
        parseArgs [] opts = ([], opts)

        compileFile file opts h =
          do tailText <- if tailInput opts
                           then hGetContents h
                           else compileApl h
             tailProg <- parseString tailText file
             let hsText = toHs opts $ convertProgram tailProg
             if runProgram opts then runGhc hsText else return ()

compileApl :: Handle -> IO String
compileApl handle =
  do input <- hGetContents handle
     aplt <- lookupEnv "APLT" >>= return . fromMaybe "aplt"
     (exitcode, stdout, _) <- readProcessWithExitCode aplt args input
     case exitcode of
       ExitSuccess -> return stdout
       ExitFailure n -> error $ "aplt failed with code " ++ show n
  where args = ["-c", "-s_tail", "-p_tail", "-p_types", "-silent", "-"]

runGhc :: String -> IO ()
runGhc program =
  do args <- getArgs
     putStrLn $ show args
     (exitcode, stdout, stderr) <- readProcessWithExitCode "runghc" args program
     case exitcode of
       ExitSuccess -> putStr stdout
       ExitFailure n ->
         do putStr stderr
            error $ "ghc failed with code " ++ show n
  where getArgs =
          do home <- lookupEnv "APLACC_HOME" >>=
                       return . fromMaybe (error "APLACC_HOME env var not set")
             return ["-i"++home++"/src"]
