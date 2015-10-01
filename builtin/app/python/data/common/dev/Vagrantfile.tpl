# Generated by Otto, do not edit!
#
# This is the Vagrantfile generated by Otto for the development of
# this application/service. It should not be hand-edited. To modify the
# Vagrantfile, use the Appfile.

Vagrant.configure("2") do |config|
  config.vm.box = "hashicorp/precise64"

  # Host only network
  config.vm.network "private_network", ip: "{{ dev_ip_address }}"

  # Setup a synced folder from our working directory to /vagrant
  config.vm.synced_folder '{{ path.working }}', "/vagrant",
    owner: "vagrant", group: "vagrant"

  # Enable SSH agent forwarding so getting private dependencies works
  config.ssh.forward_agent = true

  # Foundation configuration (if any)
  {% for dir in foundation_dirs.dev %}
  dir = "/otto/foundation-{{ forloop.Counter }}"
  config.vm.synced_folder '{{ dir }}', dir
  config.vm.provision "shell", inline: "cd #{dir} && bash #{dir}/main.sh"
  {% endfor %}

  # Load all our fragments here for any dependencies.
  {% for fragment in dev_fragments %}
  {{ fragment|read }}
  {% endfor %}

  # Install Python build environment
  config.vm.provision "shell", inline: $script_python
end

$script_python = <<SCRIPT
set -o nounset -o errexit -o pipefail -o errtrace

error() {
   local sourcefile=$1
   local lineno=$2
   echo "ERROR at ${sourcefile}:${lineno}; Last logs:"
   grep otto /var/log/syslog | tail -n 20
}
trap 'error "${BASH_SOURCE}" "${LINENO}"' ERR

# otto-exec: execute command with output logged but not displayed
oe() { "$@" 2>&1 | logger -t otto > /dev/null; }

# otto-log: output a prefixed message
ol() { echo "[otto] $@"; }

# Make it so that `vagrant ssh` goes directly to the correct dir
echo "cd /vagrant" >> "/home/vagrant/.bashrc"
# Make it so that the python venv is automatically sourced
echo ". /home/vagrant/virtualenv/bin/activate" >> "/home/vagrant/.bashrc"

# Configuring SSH for faster login
if ! grep "UseDNS no" /etc/ssh/sshd_config >/dev/null; then
  echo "UseDNS no" | sudo tee -a /etc/ssh/sshd_config >/dev/null
  oe sudo service ssh restart
fi

export DEBIAN_FRONTEND=noninteractive

ol "Adding apt repositories and updating..."
oe sudo apt-get update
oe sudo apt-get install -y python-software-properties software-properties-common apt-transport-https
oe sudo add-apt-repository -y ppa:fkrull/deadsnakes
oe sudo apt-get update

export PYTHON_VERSION="{{ python_version }}"

ol "Installing Python and supporting packages..."
export DEBIAN_FRONTEND=noninteractive
oe sudo apt-get install -y bzr git mercurial build-essential \
  libpq-dev zlib1g-dev software-properties-common \
  libsqlite3-dev \
  python$PYTHON_VERSION python$PYTHON_VERSION-dev

ol "Installing pip and virtualenv..."
oe python$PYTHON_VERSION <(wget -q -O - https://bootstrap.pypa.io/get-pip.py)
oe pip install virtualenv

ol "Setting up virtualenv in /home/vagrant/virtualenv..."
oe virtualenv "/home/vagrant/virtualenv"
oe chown -R vagrant:vagrant "/home/vagrant/virtualenv"

ol "Configuring Git to use SSH instead of HTTP so we can agent-forward private repo auth..."
oe git config --global url."git@github.com:".insteadOf "https://github.com/"
SCRIPT
