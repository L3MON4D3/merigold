gen_guestkeys:
	ssh-keygen -N "" -f ./secrets/ed25519_key -C ""

gen_pds:
	#!/usr/bin/env bash
	# from https://edouard.paris/notes/setup-atproto-pds-with-nixos/
	{
		# Generate JWT secret
		JWT_SECRET=$(openssl rand --hex 16)
		echo "PDS_JWT_SECRET=$JWT_SECRET"

		# Generate admin password
		ADMIN_PASSWORD=$(openssl rand --hex 16)
		echo "PDS_ADMIN_PASSWORD=$ADMIN_PASSWORD"

		# Generate PLC rotation key
		PLC_KEY=$(openssl ecparam --name secp256k1 --genkey --noout --outform DER | tail --bytes=+8 | head --bytes=32 | xxd --plain --cols 32)
		echo "PDS_PLC_ROTATION_KEY_K256_PRIVATE_KEY_HEX=$PLC_KEY"
	} > ./secrets/pds_env
