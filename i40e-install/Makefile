
all:
	@echo "install or uninstall"

install:
	cp -v run-after.sh /opt/
	cp -v cw-after.service /lib/systemd/system/
	systemctl daemon-reload
	systemctl enable cw-after.service
	@echo
	cp -v i40e-dkms-install.sh /opt/
	cp -v i40e-dkms-install.service /lib/systemd/system/
	systemctl daemon-reload
	systemctl enable i40e-dkms-install.service

uninstall:
	-systemctl disable cw-after.service
	rm -f /lib/systemd/system/cw-after.service
	rm -f /opt/run-after.sh
	systemctl daemon-reload
	@echo
	-systemctl disable i40e-dkms-install.service
	rm -f /lib/systemd/system/i40e-dkms-install.service
	rm -f /opt/i40e-dkms-install.sh
	systemctl daemon-reload
	rm -f /var/lib/i40e.done
	-dkms remove i40e/2.4.6 --all

clean:
	rm -f *~

.PHONY: all default clean
