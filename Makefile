dir1 := dir
dir2 := malicious_dir
n := 2

.PHONY: all antivirus restore create_directory antivirus-cron

all: antivirus

create_directory:
	mkdir -p $(dir1) $(dir2)

antivirus: create_directory
	./antivirusd.sh $(dir1) $(dir2) $(n)

restore: create_directory
	./restore.sh $(dir1) $(dir2)

antivirus-cron: create_directory
	./antivirus-cron.sh $(dir1) $(dir2)


