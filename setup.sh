#!/bin/bash
# Proxmox Host Setup - Environment Setup Script
# This script sets up all dependencies for the Proxmox Host Setup project using pyenv

set -e  # Exit on any error

echo "🚀 Setting up Proxmox Host Setup environment with pyenv..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if pyenv is installed
check_pyenv() {
    if ! command -v pyenv &> /dev/null; then
        print_error "pyenv is not installed. Please install pyenv and try again."
        print_error "Visit: https://github.com/pyenv/pyenv#installation"
        exit 1
    fi
    
    pyenv_version=$(pyenv --version | cut -d' ' -f2)
    print_status "Found pyenv $pyenv_version"
}

# Check if Python 3.12 is available
check_python() {
    if ! pyenv versions | grep -q "3.12"; then
        print_warning "Python 3.12 not found in pyenv. Installing..."
        pyenv install 3.12.0
    fi
    
    print_status "Python 3.12 is available"
}

# Create ansible virtual environment
create_ansible_env() {
    print_status "Creating ansible virtual environment..."
    
    # Create virtual environment if it doesn't exist
    if ! pyenv versions | grep -q "ansible"; then
        pyenv virtualenv 3.12.0 ansible
        print_success "Created ansible virtual environment"
    else
        print_status "ansible virtual environment already exists"
    fi
}

# Install Python dependencies
install_python_deps() {
    print_status "Installing Python dependencies..."
    
    # Activate ansible environment
    pyenv activate ansible
    
    # Upgrade pip
    pip install --upgrade pip
    
    # Install requirements
    print_status "Installing Python packages..."
    pip install -r requirements.txt
    
    print_success "Python dependencies installed successfully"
}

# Install Ansible collections
install_ansible_collections() {
    print_status "Installing Ansible collections..."
    
    # Activate ansible environment
    pyenv activate ansible
    
    ansible-galaxy collection install -r requirements.yml
    
    print_success "Ansible collections installed successfully"
}

# Verify installation
verify_installation() {
    print_status "Verifying installation..."
    
    # Activate ansible environment
    pyenv activate ansible
    
    # Check Ansible version
    ansible_version=$(ansible --version | head -n1)
    print_status "$ansible_version"
    
    # Check if required collections are installed
    if ansible-galaxy collection list | grep -q "community.general"; then
        print_success "community.general collection installed"
    else
        print_error "community.general collection not found"
        exit 1
    fi
    
    if ansible-galaxy collection list | grep -q "community.docker"; then
        print_success "community.docker collection installed"
    else
        print_error "community.docker collection not found"
        exit 1
    fi
    
    print_success "Installation verification completed"
}

# Create activation script
create_activation_script() {
    print_status "Creating activation script..."
    
    cat > activate.sh << 'EOF'
#!/bin/bash
# Activate the Proxmox Host Setup environment
pyenv activate ansible
echo "🚀 Proxmox Host Setup environment activated"
echo "Run 'pyenv deactivate' to exit the virtual environment"
EOF
    
    chmod +x activate.sh
    print_success "Created activate.sh script"
}

# Main setup process
main() {
    echo "======================================"
    echo "Proxmox Host Setup - Environment Setup"
    echo "======================================"
    echo
    
    check_pyenv
    check_python
    create_ansible_env
    install_python_deps
    install_ansible_collections
    verify_installation
    create_activation_script
    
    echo
    echo "========================================="
    echo -e "${GREEN}✅ Setup completed successfully!${NC}"
    echo "========================================="
    echo
    echo "Next steps:"
    echo "1. Activate the environment: pyenv activate ansible"
    echo "2. Configure your vault password file: ~/.ssh/ansible_key.key"
    echo "3. Update the inventory file with your Proxmox host"
    echo "4. Run: ansible-playbook -i inventory main.yml --vault-password-file=~/.ssh/ansible_key.key"
    echo
}

# Run main function
main "$@"