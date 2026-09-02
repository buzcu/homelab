# Service policy

Every service should:

- pin its image version;
- persist state under `/srv/data`;
- bind web ports to localhost unless host networking is required;
- avoid publishing databases;
- have a documented backup/restore procedure;
- be independently deployable;
- be independently upgradeable.
