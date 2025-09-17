#!/bin/bash
# Proxmox Host Setup - Environment Setup Script
# This script sets up all dependencies for the Proxmox Host Setup project

set -e  # Exit on any error

echo "🚀 Setting up Proxmox Host Setup environment..."

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

# Check if Python 3 is installed
check_python() {
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 is not installed. Please install Python 3.8+ and try again."
        exit 1
    fi
    
    python_version=$(python3 --version | cut -d' ' -f2)
    print_status "Found Python $python_version"
}

# Check if pip is installed
check_pip() {
    if ! command -v pip3 &> /dev/null; then
        print_warning "pip3 not found. Installing pip..."
        python3 -m ensurepip --upgrade || {
            print_error "Failed to install pip. Please install pip manually."
            exit 1
        }
    fi
    print_status "Found pip3"
}

# Install Python dependencies
install_python_deps() {
    print_status "Installing Python dependencies..."
    
    # Create virtual environment if it doesn't exist
    if [ ! -d "venv" ]; then
        print_status "Creating virtual environment..."
        python3 -m venv venv
    fi
    
    # Activate virtual environment
    print_status "Activating virtual environment..."
    source venv/bin/activate
    
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
    
    # Activate virtual environment
    source venv/bin/activate
    
    ansible-galaxy collection install -r requirements.yml
    
    print_success "Ansible collections installed successfully"
}

# Verify installation
verify_installation() {
    print_status "Verifying installation..."
    
    # Activate virtual environment
    source venv/bin/activate
    
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
source venv/bin/activate
echo "🚀 Proxmox Host Setup environment activated"
echo "Run 'deactivate' to exit the virtual environment"
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
    
    check_python
    check_pip
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
    echo "1. Activate the environment: source activate.sh"
    echo "2. Configure your vault password file: ~/.ssh/ansible_key.key"
    echo "3. Update the inventory file with your Proxmox host"
    echo "4. Run: ansible-playbook -i inventory main.yml --ask-vault-pass"
    echo
}

# Run main function
main "$@"