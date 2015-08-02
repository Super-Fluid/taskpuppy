{-# LANGUAGE DeriveDataTypeable, OverloadedStrings, GeneralizedNewtypeDeriving #-}

------------------------------------------------------------------------------
-- | This module is where all the routes and handlers are defined for your
-- site. The 'app' function is the initializer that combines everything
-- together and is exported by this module.
module Site
  ( app
  ) where

------------------------------------------------------------------------------
import           Control.Applicative
import           Data.ByteString (ByteString)
import           Data.Monoid
import qualified Data.Text as T
import           Data.Dates
import           Data.Time.Clock
import           Data.Int
import           Data.Typeable
import           Snap.Core
import           Snap.Snaplet
import           Snap.Snaplet.Auth
--import           Snap.Snaplet.Auth.Backends.JsonFile
import           Snap.Snaplet.Heist
import           Snap.Snaplet.Session.Backends.CookieSession
import           Snap.Snaplet.PostgresqlSimple
import           Snap.Snaplet.Auth.Backends.PostgresqlSimple
import           Snap.Util.FileServe
import           Heist
import qualified Heist.Interpreted as I
import           Database.PostgreSQL.Simple.FromRow
import           Database.PostgreSQL.Simple.FromField

------------------------------------------------------------------------------
import           Application


------------------------------------------------------------------------------
-- | Render login form
handleLogin :: Maybe T.Text -> Handler App (AuthManager App) ()
handleLogin authError = heistLocal (I.bindSplices errs) $ render "login"
  where
    errs = maybe mempty splice authError
    splice err = "loginError" ## I.textSplice err


------------------------------------------------------------------------------
-- | Handle login submit
handleLoginSubmit :: Handler App (AuthManager App) ()
handleLoginSubmit =
    loginUser "login" "password" Nothing
              (\_ -> handleLogin err) (redirect "/")
  where
    err = Just "Unknown user or password"


------------------------------------------------------------------------------
-- | Logs out and redirects the user to the site index.
handleLogout :: Handler App (AuthManager App) ()
handleLogout = logout >> redirect "/"


------------------------------------------------------------------------------
-- | Handle new user form submit
handleNewUser :: Handler App (AuthManager App) ()
handleNewUser = method GET handleForm <|> method POST handleFormSubmit
  where
    handleForm = render "new_user"
    handleFormSubmit = registerUser "login" "password" >> redirect "/"


------------------------------------------------------------------------------
-- | The application's routes.
routes :: [(ByteString, Handler App App ())]
routes = [ ("/login",    with auth handleLoginSubmit)
         , ("/logout",   with auth handleLogout)
         , ("/new_user", with auth handleNewUser)
         , ("",          serveDirectory "static")
         ]


------------------------------------------------------------------------------
-- | The application initializer.
app :: SnapletInit App App
app = makeSnaplet "taskpuppy" "A fast and simple issue tracker." Nothing $ do
    db <- nestSnaplet "db" db pgsInit
    h <- nestSnaplet "" heist $ heistInit "templates"
    s <- nestSnaplet "sess" sess $
           initCookieSessionManager "site_key.txt" "sess" (Just 3600)

    -- NOTE: We're using initJsonFileAuthManager here because it's easy and
    -- doesn't require any kind of database server to run.  In practice,
    -- you'll probably want to change this to a more robust auth backend.
    a <- nestSnaplet "auth" auth $ initPostgresAuth sess db
    addRoutes routes
    addAuthSplices h auth
    return $ App h s a db

---------------------------------------------------------------------------
-- | Data

newtype ProjectID = ProjectID Int32
    deriving (Show, Eq, Ord, Enum, Read, FromField)

newtype IssueID = IssueID Int32
    deriving (Show, Eq, Ord, Enum, Read, FromField)

newtype UpdateID = UpdateID Int32
    deriving (Show, Eq, Ord, Enum, Read, FromField)

data Project = Project
  { projectId       :: ProjectID
  , projectTitle    :: T.Text
  , projectDetails  :: T.Text
  , owner           :: UserId -- from Snap.Snaplet.Auth
  } deriving (Show)
  
instance FromRow Project where
    fromRow = Project <$> field <*> field <*> field <*> field
  
data IssueStatus = UnassignedIssue 
                 | AssignedIssue 
                 | ResolvedIssue 
                 | ClosedIssue
    deriving (Show, Typeable)

data IssuePriority = NormalPriority 
                   | UrgentPriority
    deriving (Show, Typeable)

instance FromField IssueStatus where
    fromField f bs
      | bs == Nothing                   = returnError UnexpectedNull f ""
      | bs == Just "unassigned"         = pure UnassignedIssue
      | bs == Just "assigned"           = pure AssignedIssue
      | bs == Just "resolved"           = pure ResolvedIssue
      | bs == Just "closed"             = pure ClosedIssue
      | otherwise                       = returnError ConversionFailed f ""

instance FromField IssuePriority where
    fromField f bs
      | bs == Nothing                   = returnError UnexpectedNull f ""
      | bs == Just "normal"             = pure NormalPriority
      | bs == Just "urgent"             = pure UrgentPriority
      | otherwise                       = returnError ConversionFailed f ""


data Issue = Issue
  { issueId     :: IssueID
  , issueTitle  :: T.Text
  , creator     :: UserId
  , dateCreated :: UTCTime
  , lastUpdated :: UTCTime
  , assignedTo  :: UserId
  , issueStatus :: IssueStatus
  , issuePriority :: IssuePriority
  , forProject  :: ProjectID
  } deriving (Show)

instance FromRow Issue where
    fromRow = Issue <$> field <*> field <*> field <*> field <*> field <*> field <*> field <*> field <*> field

  
data IssueUpdate = IssueUpdate
  { updateId    :: UpdateID
  , forIssue    :: IssueID
  , author      :: UserId
  , oldStatus   :: Maybe IssueStatus
  , oldPriority :: Maybe IssuePriority
  , oldAssignee :: Maybe UserId
  , datePublished :: UTCTime
  } deriving (Show)

instance FromRow IssueUpdate where
    fromRow = IssueUpdate <$> field <*> field <*> field <*> field <*> field <*> field <*> field




