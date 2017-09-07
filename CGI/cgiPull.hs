{-# OPTIONS_GHC -fno-warn-tabs #-}
{-# LANGUAGE DuplicateRecordFields#-}
import Network.CGI 
import System.Process
import System.Exit
import Control.Monad.Trans.Class
import TransferData
import ParseUserInfo
import GitPush
import qualified Data.ByteString.Lazy.Char8 as B


cgiMain :: CGI CGIResult
cgiMain = do
        --get header and check for secret token authorization
        header <- requestHeader "X-Gitlab-Token"
        case header of
            Nothing -> error "Error no header."
            Just h -> do
            if(h == "eNbbFFBqgBq5TSGdUtWr9gw4WXptmKbKQKp3P8bPAksYyKvx")
                then do
                    _ <- listUser
                    inputs <- getBody
                    user <- parseJSON $ B.pack inputs
                    setGitConfigs
                    let branchRef = ref user       -- used for getting branch name  
                    let branch = getBranchName branchRef 0 
                    _ <- liftIO.begin.show $ "Pulling on branch name: "++branch
                    let url = git_http_url ((repository user) :: Repo)
                    let repoName = name ((project user) :: Project)
                    let hwkNum = parseHwkNum repoName
                    _ <- liftIO.begin.show $ "Homework number: "++hwkNum
                    let repoFolder = "/usr/lib/cgi-bin/Repos/Hwk_1"
                    if(branch == "solution")    -- only pull and grade on "solution" branch
                      then do 
                            runAHGSetup url hwkNum $ "/usr/lib/cgi-bin/Repos/"++repoName++"/"
                      else output ""
                    output ""
            else do
                _ <- liftIO.begin.show $ "You are not authenticated."
                output ""
                
setGitConfigs :: CGI CGIResult
setGitConfigs = do
    _ <- liftIO.begin.show $ "Calling bash script"
    (extCode,stndOut,stndErr) <- liftIO $ readProcessWithExitCode "./setGitConfig.sh" [] ""
    case extCode of
       ExitSuccess -> do 
                   _ <- liftIO.begin.show $ "Bash script finished"
                   output ""
       _ -> do
             _ <- liftIO.begin.show $ "Standard out:"++stndOut
             _ <- liftIO.begin.show $ "Standard error:"++stndErr
             output ""  
                 
                
runAHGSetup :: String -> String -> String -> CGI CGIResult
runAHGSetup url hwkNum repoFolder = do
    _ <- liftIO.begin.show $ "Running AHG Setup"
    _ <- liftIO.begin.show $ "Repo folder used for git add, commit, and push: "++repoFolder
    (extCode,stndOut,stndErr) <- liftIO $ readProcessWithExitCode "/usr/lib/cgi-bin/AHG/CGI/Hwk/./SetupAHG" [hwkNum, repoFolder] ""
    case extCode of
       ExitSuccess -> do 
                   _ <- liftIO.begin.show $ "Finished grading homework, pushing grade report to repo"
                   _ <- liftIO.gitAddGradeReport $ repoFolder
                   _ <- liftIO $ gitCommit  "Pushing grade report." repoFolder
                   let gitUrl = getGitUrlWithCreds "root" "password" url 0
                   _ <- liftIO.begin.show $ "Git url for pushing repo: "++gitUrl
                   _ <- liftIO $ gitPushGradeReport url repoFolder
                   output ""
       _ -> do
             _ <- liftIO.begin.show $ stndOut
             _ <- liftIO.begin.show $ stndErr
             output ""
  
                                   
parseHwkNum :: String -> String
parseHwkNum [] = []
parseHwkNum (x:xs) = if (x == '_')
                        then xs
                        else parseHwkNum xs
                        
getBranchName :: String -> Int -> String
getBranchName [] _ = []
getBranchName (x:xs) slashCount | x == '/' = if(slashCount == 1)
                                                then xs
                                                else getBranchName xs (slashCount + 1)
                                | otherwise = getBranchName xs slashCount

listUser :: CGI CGIResult
listUser = do
	 (exitCode, stnOut, stdErr) <- liftIO $ readProcessWithExitCode "whoami" [] ""
	 case exitCode of
	   ExitSuccess -> do
	   	       _ <- liftIO.begin.show $ "Current user: "++stnOut
		       output ""
	   _ -> do
	     _ <- liftIO.begin.show $ "standard error: "++stdErr
	     output ""
                               

main :: IO ()
main = runCGI (handleErrors cgiMain)