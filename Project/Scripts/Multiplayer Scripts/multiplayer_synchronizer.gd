extends MultiplayerSynchronizer

func _ready():
	# Configure what to sync
	replication_config = SceneReplicationConfig.new()
	
	# Sync position, rotation and velocity
	replication_config.add_property(".:position")
	replication_config.add_property(".:rotation")
	replication_config.add_property(".:velocity")
	
	# Set this peer as the authority
	if get_parent().is_multiplayer_authority():
		set_multiplayer_authority(multiplayer.get_unique_id())
