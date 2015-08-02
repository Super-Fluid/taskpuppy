-- table snap_auth_user holds users

create table projects (
  id                    serial                          primary key,
  title                 text                            not null,
  details               text                            ,
  owner                 references snap_auth_user(uid)  not null,
);

create type issue_status as enum ('unassigned', 'assigned', 'resolved', 'closed');
create type issue_priority as enum ('normal', 'urgent');

create table issues (
  id                    serial                          primary key,
  title                 text                            not null,
  creator               references snap_auth_user(uid)  not null,
  last_updated          timestamp with time zone        not null, -- will be the same as dateCreated for new issues
  date_created          timestamp with time zone        not null,
  assigned_to           references snap_auth_user(uid)  , -- null: unassigned
  issue_status          issue_status                    not null,
  issue_priority        issue_priority                  not null,
  project               references projects(id)         , -- null is to save a draft that is not assigned.. (should be very rare)
);

create table issue_updates (
  id                    serial                          primary key,
  issue                 references issues(id)           not null,
  author                references snap_auth_user(uid)  not null,
  old_status            issue_status                    , -- null: this update didn't change the status
  old_priority          issue_priority                  , -- null: this update didn't change the priority
  old_assignee          references snap_auth_user(uid)  , -- null: this update didn't reassign the issue
  date_published        timestamp with time zone        , -- null: draft
);

create table watches_issue_map (
  watcher               references snap_auth_user(uid)  not null,
  issue                 references issues(id)           not null,
);