{-# LANGUAGE CPP #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Provides actions for Webhook API interactions
module Discord.Internal.Rest.Webhook
  ( CreateWebhookOpts(..)
  , ExecuteWebhookWithTokenOpts(..)
  , ModifyWebhookOpts(..)
  , WebhookContent(..)
  , WebhookRequest(..)
  ) where

import           Data.Aeson
import qualified Data.Text as T
import qualified Data.ByteString as B
import qualified Data.ByteString.Lazy as BL
import           Network.HTTP.Req ((/:))
import qualified Network.HTTP.Req as R
import Network.HTTP.Client (RequestBody (RequestBodyBS))
import Network.HTTP.Client.MultipartFormData (partBS, partFileRequestBody)

import Discord.Internal.Rest.Prelude
import Discord.Internal.Types

-- aeson introduced type name for json key (text)
-- https://github.com/haskell/aeson/issues/881
# if MIN_VERSION_aeson(2, 0, 0)
import qualified Data.Aeson.Key as Key
toKey :: T.Text -> Key.Key
toKey = Key.fromText
# else
toKey :: T.Text -> T.Text
toKey = id
# endif

instance Request (WebhookRequest a) where
  majorRoute = webhookMajorRoute
  jsonRequest = webhookJsonRequest

-- | Data constructor for requests. See <https://discord.com/developers/docs/resources/ API>
data WebhookRequest a where
  CreateWebhook :: ChannelId -> CreateWebhookOpts -> WebhookRequest Webhook
  GetChannelWebhooks :: ChannelId -> WebhookRequest [Webhook]
  GetGuildWebhooks :: GuildId -> WebhookRequest [Webhook]
  -- GetWebhook :: WebhookId -> WebhookRequest Webhook
  GetWebhook :: WebhookId -> Maybe WebhookToken -> WebhookRequest Webhook
  ModifyWebhook :: WebhookId -> Maybe WebhookToken -> ModifyWebhookOpts
                                      -> WebhookRequest Webhook
  DeleteWebhook :: WebhookId -> Maybe WebhookToken -> WebhookRequest ()
  ExecuteWebhook :: WebhookId -> WebhookToken -> ExecuteWebhookWithTokenOpts
                                       -> WebhookRequest ()
  -- we don't support slack and github compatible webhooks because you should
  --  just use execute webhook
  GetWebhookMessage :: WebhookId -> WebhookToken -> MessageId -> WebhookRequest Message
  EditWebhookMessage :: WebhookId -> WebhookToken -> MessageId -> T.Text -- currently we don't support the full range of edits
                                          -> WebhookRequest Message
  DeleteWebhookMessage :: WebhookId -> WebhookToken -> MessageId -> WebhookRequest ()

data ModifyWebhookOpts = ModifyWebhookOpts
  { modifyWebhookOptsName          :: Maybe T.Text
  , modifyWebhookOptsAvatar        :: Maybe T.Text
  , modifyWebhookOptsChannelId     :: Maybe ChannelId
  } deriving (Show, Read, Eq, Ord)

instance ToJSON ModifyWebhookOpts where
  toJSON ModifyWebhookOpts{..} = object [(toKey name, val) | (name, Just val) <-
                         [("channel_id",   toJSON <$> modifyWebhookOptsChannelId),
                          ("name",   toJSON <$> modifyWebhookOptsName),
                          ("avatar",  toJSON <$> modifyWebhookOptsAvatar) ] ]

data CreateWebhookOpts = CreateWebhookOpts
  { createWebhookOptsName          :: T.Text
  , createWebhookOptsAvatar        :: Maybe T.Text
  } deriving (Show, Read, Eq, Ord)

instance ToJSON CreateWebhookOpts where
  toJSON CreateWebhookOpts{..} = object [(name, val) | (name, Just val) <-
                         [("name",   toJSON <$> Just createWebhookOptsName),
                          ("avatar",  toJSON <$> createWebhookOptsAvatar) ] ]

data ExecuteWebhookWithTokenOpts = ExecuteWebhookWithTokenOpts
  { executeWebhookWithTokenOptsUsername      :: Maybe T.Text
  , executeWebhookWithTokenOptsContent       :: WebhookContent
  } deriving (Show, Read, Eq, Ord)

data WebhookContent = WebhookContentText T.Text
                    | WebhookContentFile T.Text B.ByteString
                    | WebhookContentEmbeds [CreateEmbed]
  deriving (Show, Read, Eq, Ord)

webhookContentJson :: WebhookContent -> [(T.Text, Maybe Value)]
webhookContentJson c = case c of
                      WebhookContentText t -> [("content", Just (toJSON t))]
                      WebhookContentFile _ _  -> []
                      WebhookContentEmbeds e -> [("embeds", Just (toJSON (createEmbed <$> e)))]

instance ToJSON ExecuteWebhookWithTokenOpts where
  toJSON ExecuteWebhookWithTokenOpts{..} = object $ [(toKey name, val) | (name, Just val) <-
                         [("username",   toJSON <$> executeWebhookWithTokenOptsUsername)]
                           <> webhookContentJson executeWebhookWithTokenOptsContent
                         ]

webhookMajorRoute :: WebhookRequest a -> String
webhookMajorRoute ch = case ch of
  (CreateWebhook c _) ->    "aaaaaahook " <> show c
  (GetChannelWebhooks c) -> "aaaaaahook " <> show c
  (GetGuildWebhooks g) ->   "aaaaaahook " <> show g
  (GetWebhook w _) ->       "getwebhook " <> show w
  (ModifyWebhook w _ _) ->  "modifyhook " <> show w
  (DeleteWebhook w _) ->    "deletehook " <> show w
  (ExecuteWebhook w _ _) ->  "executehk " <> show w
  (GetWebhookMessage w _ _) -> "gethkmsg " <> show w
  (EditWebhookMessage w _ _ _) -> "edithkmsg " <> show w
  (DeleteWebhookMessage w _ _) -> "delhkmsg " <> show w

webhookJsonRequest :: WebhookRequest r -> JsonRequest
webhookJsonRequest ch = case ch of
  (CreateWebhook channel patch) ->
    let body = pure (R.ReqBodyJson patch)
    in Post (baseUrl /: "channels" // channel /: "webhooks") body  mempty

  (GetChannelWebhooks c) ->
    Get (baseUrl /: "channels" // c /: "webhooks")  mempty

  (GetGuildWebhooks g) ->
    Get (baseUrl /: "guilds" // g /: "webhooks")  mempty

  (GetWebhook w t) ->
    Get (baseUrl /: "webhooks" // w /? t)  mempty

  (ModifyWebhook w t p) ->
    Patch (baseUrl /: "webhooks" // w /? t) (pure (R.ReqBodyJson p))  mempty

  (DeleteWebhook w t) ->
    Delete (baseUrl /: "webhooks" // w /? t)  mempty

  (ExecuteWebhook w tok o) ->
    case executeWebhookWithTokenOptsContent o of
      WebhookContentFile name text  ->
        let part = partFileRequestBody "file" (T.unpack name) (RequestBodyBS text)
            body = R.reqBodyMultipart [part]
        in Post (baseUrl /: "webhooks" // w R./~ tok) body mempty
      WebhookContentText _ ->
        let body = pure (R.ReqBodyJson o)
        in Post (baseUrl /: "webhooks" // w R./~ tok) body mempty
      WebhookContentEmbeds embeds ->
        let mkPart (name,content) = partFileRequestBody name (T.unpack name) (RequestBodyBS content)
            uploads CreateEmbed{..} = [(n,c) | (n, Just (CreateEmbedImageUpload c)) <-
                                          [ ("author.png", createEmbedAuthorIcon)
                                          , ("thumbnail.png", createEmbedThumbnail)
                                          , ("image.png", createEmbedImage)
                                          , ("footer.png", createEmbedFooterIcon) ]]
            parts =  map mkPart (concatMap uploads embeds)
            partsJson = [partBS "payload_json" $ BL.toStrict $ encode $ toJSON $ object ["embed" .= createEmbed e] | e <- embeds]
            body = R.reqBodyMultipart (partsJson ++ parts)
        in Post (baseUrl /: "webhooks" // w /: unToken tok) body mempty

  (GetWebhookMessage w t m) ->
    Get (baseUrl /: "webhooks" // w R./~ t /: "messages" // m)  mempty

  (EditWebhookMessage w t m p) ->
    Patch (baseUrl /: "webhooks" // w R./~ t /: "messages" // m) (pure (R.ReqBodyJson p))  mempty

  (DeleteWebhookMessage w t m) ->
    Delete (baseUrl /: "webhooks" // w R./~ t /: "messages" // m)  mempty
