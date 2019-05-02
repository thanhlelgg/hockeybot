Vagrant.configure("2") do |config|
config.vm.box = "ubuntu/trusty64"      #<--14.04 LTS
config.vm.provider "virtualbox" do |v|
 v.memory = 6144
 v.cpus = 2
end
config.vm.provision "shell", path: "scripts/vagrant-setup.sh", privileged: false
end