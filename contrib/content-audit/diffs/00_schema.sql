CREATE DATABASE IF NOT EXISTS cmp DEFAULT CHARACTER SET utf8mb4;

DROP TABLE IF EXISTS cmp.findings;
CREATE TABLE cmp.findings (
    zone        INT UNSIGNED NOT NULL,
    topic       VARCHAR(32)  NOT NULL,
    entity_kind VARCHAR(16)  NOT NULL,
    entity_id   INT UNSIGNED NOT NULL,
    field       VARCHAR(48)  NOT NULL,
    v_value     VARCHAR(128),
    mz_value    VARCHAR(128),
    tw_value    VARCHAR(128),
    ac_value    VARCHAR(128),
    strength    VARCHAR(8)   NOT NULL,
    note        VARCHAR(255) NOT NULL DEFAULT '',
    KEY ix_zone_topic (zone, topic),
    KEY ix_strength (strength)
) ENGINE=InnoDB;

-- The consensus rule, in one place.
--
-- tortoise-wow is a fork of the live database, so its agreement carries no
-- information and it is not an argument here. It enters a report only where it
-- disagrees, as context on a finding the peers already raised.
--
-- A NULL peer is abstaining - it cannot express this field at all - and an
-- abstention never strengthens a finding. This also covers v itself being
-- NULL (the entity is missing from the realm under audit): '<=>' treats
-- NULL as a real value there, so a v that is absent while both independent
-- peers agree on a value still reads as both peers differing from v, which
-- is exactly the missing-entity finding this audit must not lose.
DROP FUNCTION IF EXISTS cmp.strength;
CREATE FUNCTION cmp.strength(v VARCHAR(128), mz VARCHAR(128), ac VARCHAR(128))
RETURNS VARCHAR(8) DETERMINISTIC
RETURN CASE
    WHEN mz IS NULL AND ac IS NULL                      THEN ''
    WHEN mz IS NOT NULL AND ac IS NOT NULL
         AND NOT (v <=> mz) AND NOT (v <=> ac)
         AND (mz <=> ac)                                THEN 'strong'
    WHEN NOT (v <=> mz) OR NOT (v <=> ac)               THEN 'weak'
    ELSE ''
END;
