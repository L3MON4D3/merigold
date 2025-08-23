run:
	nix build
	sudo ./result/bin/macvtap-up
	sudo ./result/bin/microvm-run
	sudo ./result/bin/macvtap-down

gen_guestkeys:
	ssh-keygen -N "" -f ./secrets/ed25519_key -C ""
