-- | Provides types and encoding/decoding code. Types should be identical to those provided
--   in the Discord API documentation.
module Discord.Internal.Types
  ( module Discord.Internal.Types.Prelude
  , module Discord.Internal.Types.Channel
  , module Discord.Internal.Types.Events
  , module Discord.Internal.Types.Gateway
  , module Discord.Internal.Types.Guild
  , module Discord.Internal.Types.User
  , module Discord.Internal.Types.Embed
  , module Discord.Internal.Types.ApplicationCommands
  , module Discord.Internal.Types.Interactions
  , module  Discord.Internal.Types.Components
  , module Data.Aeson
  , module Data.Time.Clock
  , userFacingEvent
  ) where

import Discord.Internal.Types.Channel
import Discord.Internal.Types.Events
import Discord.Internal.Types.Gateway
import Discord.Internal.Types.Guild
import Discord.Internal.Types.User
import Discord.Internal.Types.Embed
import Discord.Internal.Types.Prelude
import Discord.Internal.Types.ApplicationCommands
import Discord.Internal.Types.Interactions
import Discord.Internal.Types.Components

import Data.Aeson (Object)
import Data.Time.Clock (UTCTime(..))


userFacingEvent :: EventInternalParse -> Event
userFacingEvent event = case event of
  InternalReady a b c d e -> Ready a b c d e
  InternalResumed a -> Resumed a
  InternalChannelCreate a -> ChannelCreate a
  InternalChannelUpdate a -> ChannelUpdate a
  InternalChannelDelete a -> ChannelDelete a
  InternalChannelPinsUpdate a b -> ChannelPinsUpdate a b
  InternalGuildCreate a b -> GuildCreate a b
  InternalGuildUpdate a -> GuildUpdate a
  InternalGuildDelete a -> GuildDelete a
  InternalGuildBanAdd a b -> GuildBanAdd a b
  InternalGuildBanRemove a b -> GuildBanRemove a b
  InternalGuildEmojiUpdate a b -> GuildEmojiUpdate a b
  InternalGuildIntegrationsUpdate a -> GuildIntegrationsUpdate a
  InternalGuildMemberAdd a b -> GuildMemberAdd a b
  InternalGuildMemberRemove a b -> GuildMemberRemove a b
  InternalGuildMemberUpdate a b c d -> GuildMemberUpdate a b c d
  InternalGuildMemberChunk a b -> GuildMemberChunk a b
  InternalGuildRoleCreate a b -> GuildRoleCreate a b
  InternalGuildRoleUpdate a b -> GuildRoleUpdate a b
  InternalGuildRoleDelete a b -> GuildRoleDelete a b
  InternalMessageCreate a -> MessageCreate a
  InternalMessageUpdate a b -> MessageUpdate a b
  InternalMessageDelete a b -> MessageDelete a b
  InternalMessageDeleteBulk a b -> MessageDeleteBulk a b
  InternalMessageReactionAdd a -> MessageReactionAdd a
  InternalMessageReactionRemove a -> MessageReactionRemove a
  InternalMessageReactionRemoveAll a b -> MessageReactionRemoveAll a b
  InternalMessageReactionRemoveEmoji a -> MessageReactionRemoveEmoji a
  InternalPresenceUpdate a -> PresenceUpdate a
  InternalTypingStart a -> TypingStart a
  InternalUserUpdate a -> UserUpdate a
  InternalUnknownEvent a b -> UnknownEvent a b
