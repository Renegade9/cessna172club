/*
 *  Create PostgreSQL table for Cessna 172 Club Members
 */

CREATE TABLE c172_members (
    member_id           integer      NOT NULL,
    member_name         varchar(50)  NOT NULL,
    home_airport        varchar(120),
    avatar_url          varchar(255),
    show_avatar         boolean     DEFAULT FALSE,
    total_posts         numeric(6)  DEFAULT 0,
    tz_offset           numeric(4),
    latitude            numeric(9,6),
    longitude           numeric(9,6),
    geocode_error       varchar(2000),
    airport_short_name  varchar(2000),
    airport_long_name   varchar(2000),
    last_update_ts      timestamp with time zone,
    CONSTRAINT c172_members_pk PRIMARY KEY (member_id)
);
