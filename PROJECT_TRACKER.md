# Project Tracker - Hams Social

Last updated: 2026-03-02 (Smart Trust System rollout)

## Status Legend
- DONE: implemented and working in app
- IN_PROGRESS: partially implemented
- TODO: not implemented yet

## 1) User and Profile
- DONE: username + public profile route (`/u/:username`)
- DONE: profile photo/frame/banner via store active items
- DONE: bio field
- DONE: profile views counter (with security rules)
- DONE: level + XP progress display
- DONE: badges display
- IN_PROGRESS: "active items" display exists through theme/frame/banner usage, but no dedicated summary panel
- DONE: reputation score + trust level (A/B/C/D) stored and shown in profile
- TODO: interest tags
- TODO: privacy settings:
  - who can message (everyone / friends only)
  - show/hide views
  - show/hide last seen
  - allow/deny anonymous messages

## 2) Messages
- DONE: inbox flow + anonymous message send
- IN_PROGRESS: report/delete/hide handling exists in parts, needs final unified UX for all message actions
- IN_PROGRESS: reply flow (private/public) exists, needs final polish and consistency
- DONE: soft daily limits for anonymous send and public posts (UI-friendly message)
- TODO: semi-anonymous mode (hints like mutual friend/city)
- TODO: visible identity mode
- TODO: message style templates (color/font/template from store)
- TODO: full question mode on profile

## 3) Replies
- DONE: private reply path exists
- DONE: public reply as post exists
- IN_PROGRESS: reactions are currently like-based; "useful/funny" reactions not complete
- DONE: moderation hide/unhide on posts by admin

## 4) Friends
- DONE: send/cancel/accept/decline friend requests
- DONE: friends list
- DONE: friend-based actions integrated with chat opening
- TODO: special anonymous-to-friend marker
- TODO: explicit game invite flow after friendship

## 5) Private Chat
- DONE: 1-1 chat, realtime messages, chat list
- DONE: blocked-user protections in chat logic/rules
- IN_PROGRESS: "friends only chat" policy needs final strict enforcement check across all entry points
- TODO: last seen optional toggle in settings/UI

## 6) Safety and Moderation
- DONE: reports collection and report dialog
- DONE: admin detection from `config/admins` (no claims/cloud functions)
- DONE: admin reports page with tabs (posts/profiles/all)
- DONE: hide/unhide post actions
- DONE: ban/unban user actions
- DONE: moderation audit log (`moderation_actions`)
- DONE: banned account gate page + app routing gate
- DONE: anti-duplicate post reporting with reporters subcollection
- DONE: reports count update transaction on posts
- DONE: auto-hide post by reports threshold implemented in app (`20` reports)
- DONE: reputation adjustments on moderation actions:
  - hide post: -5
  - unhide post: +2
  - ban user: -30

## 7) Admin Dashboard
- DONE: dashboard page exists with aggregate counts
- DONE: error copy button in app to copy full exception text/link
- IN_PROGRESS: Firestore index dependency handling (requires `posts.status` collection-group single-field index enabled)
- DONE: top reported posts section added
- DONE: latest moderation actions section added

## 8) Gamification and Store
- DONE: daily missions base system
- DONE: XP/level and some badge progression
- DONE: store purchase/activate for theme/frame/banner
- TODO: game-linked rewards integration

## 9) Games Roadmap (as requested)
- TODO: Ludo (social)
- TODO: Snakes and Ladders (social)
- TODO: Endless Runner (solo)
- TODO: Trivia Quiz (solo/social)
- TODO: matchmaking/private rooms/game chat/leaderboards
- TODO: scoring model integration with XP/coins/profile

## 10) Infra / Rules / Indexes
- DONE: Firestore rules migrated to admin-from-config style
- DONE: moderation/banned/reporters logic in rules
- DONE: firebase indexes config file added:
  - `firestore.indexes.json` with `posts.status` collection-group ASC field override
  - `posts.reportsCount` collection-group DESC field override (for top reported dashboard list)
- DONE: deployed firestore indexes via CLI (project: `hams-social-app`)
- IN_PROGRESS: Firestore rules final alignment for auto-hide fields set by non-admin reporter path (`status`, `autoModerated`, `hiddenReason` via report increment flow)
- NOTE: if dashboard still shows index precondition, wait for index build completion then restart app

## 11) UI / Design System
- DONE: central visual tokens added (`HamsColors`, gradients, screen decorations)
- DONE: upgraded app-level themes (`theme_midnight`, `theme_classic`) with modern cards/chips/inputs/buttons
- DONE: global RTL app builder in `MaterialApp.router`
- DONE: non-breaking visual refresh applied to key pages:
  - profile page
  - inbox page
  - friends page
  - chat page

## Next Priority (recommended)
1. Apply final Firestore rules patch for auto-hide reporter update path.
2. Finalize privacy settings model + UI + rules (section 1).
3. Complete chat policy enforcement (friends-only, last seen toggle).
4. Finish message modes (semi-anonymous, identity-visible, styled templates).
5. Add reaction types beyond likes (`useful`, `funny`).
6. Start first game module with minimal playable MVP.
