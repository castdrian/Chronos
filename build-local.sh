#!/bin/sh

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
	echo -e "${BLUE}[*]${NC} $1"
}

print_success() {
	echo -e "${GREEN}[+]${NC} $1"
}

print_error() {
	echo -e "${RED}[-]${NC} $1"
}

if [ ! -f "control" ]; then
    print_error "Control file not found. Cannot continue."
    exit 1
fi

NAME=$(grep '^Name:' control | cut -d ' ' -f 2)
if [ -z "$NAME" ]; then
    print_error "Package name not found in control file. Cannot continue."
    exit 1
fi

print_status "Building package: $NAME"

IPA_FILE=$(find . -maxdepth 1 -name "*.ipa" -print -quit)
UNAME=$(uname)

print_status "Build debug version? (y/n):"
read -t 3 DEBUG_INPUT
if [ $? -gt 128 ]; then
    echo "n"
    DEBUG_ARG=""
    print_status "Building release version... (default)"
elif [[ $DEBUG_INPUT =~ ^[Yy]$ ]]; then
    DEBUG_ARG="DEBUG=1"
    print_status "Building debug version..."
else
    DEBUG_ARG=""
    print_status "Building release version..."
fi

if [ -z "$IPA_FILE" ]; then
    print_status "No ipa found. Please enter Audible ipa URL or file path:"
    read AUDIBLE_INPUT

    if [ -z "$AUDIBLE_INPUT" ]; then
        print_error "No input provided"
        exit 1
    fi

    if [[ "$AUDIBLE_INPUT" =~ ^https?:// ]]; then
        print_status "Downloading Audible ipa..."
        curl -L -o audible.ipa "$AUDIBLE_INPUT"
        if [ $? -ne 0 ]; then
            print_error "Failed to download Audible ipa"
            exit 1
        fi
        print_success "Downloaded Audible ipa"
    else
        if [ ! -f "$AUDIBLE_INPUT" ]; then
            print_error "File not found: $AUDIBLE_INPUT"
            exit 1
        fi
        print_status "Copying Audible ipa..."
        cp "$AUDIBLE_INPUT" audible.ipa
        if [ $? -ne 0 ]; then
            print_error "Failed to copy Audible ipa"
            exit 1
        fi
        print_success "Copied Audible ipa"
    fi
    IPA_FILE="audible.ipa"
fi

print_status "Building tweak..."

if [ "$UNAME" = "Darwin" ]; then
	gmake package $DEBUG_ARG
else
	make package $DEBUG_ARG
fi
if [ $? -ne 0 ]; then
	print_error "Failed to build tweak"
	exit 1
fi
print_success "Built tweak"

OUTPUT_IPA="Audible.ipa"

if [ ! -d "venv" ] || [ ! -f "venv/bin/cyan" ]; then
    print_status "Setting up Python environment..."
    [ -d "venv" ] && rm -rf venv
    python3 -m venv venv
    source venv/bin/activate
    pip install --force-reinstall https://github.com/asdfzxcvbn/pyzule-rw/archive/main.zip Pillow

    if [ $? -ne 0 ]; then
        print_error "Failed to install cyan"
        exit 1
    fi
    print_success "Installed cyan"
else
    print_status "Using existing Python environment..."
    source venv/bin/activate
fi

DEB_FILE=$(find packages -maxdepth 1 -name "*.deb" -print -quit)

print_status "Injecting tweak..."
yes | cyan -duwsgq -i "$IPA_FILE" -o "$OUTPUT_IPA" -f "$DEB_FILE"

if [ $? -ne 0 ]; then
    print_error "Failed to inject tweak"
    exit 1
fi

deactivate

print_status "Cleaning up..."
rm -rf packages

print_success "Successfully created $OUTPUT_IPA"
