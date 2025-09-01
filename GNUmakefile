# Makefile for gsauth - GNUstep Authentication Tool

# Program name
PROG = gsauth

# GNUstep configuration
GNUSTEP_CONFIG = gnustep-config
# Filter out -MMD flag to prevent .d file generation
OBJC_FLAGS = $(filter-out -MMD,$(shell $(GNUSTEP_CONFIG) --objc-flags))
GUI_LIBS = $(shell $(GNUSTEP_CONFIG) --gui-libs)

# Get GNUstep system tools path dynamically
GNUSTEP_SYSTEM_TOOLS = $(shell $(GNUSTEP_CONFIG) --variable=GNUSTEP_SYSTEM_TOOLS)

# Compiler settings
CC = clang
CFLAGS = $(OBJC_FLAGS) -Wall
LDFLAGS = $(GUI_LIBS)

# Default target
all: $(PROG)

# Build the gsauth binary
$(PROG): $(PROG).m
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)
	@rm -f $(PROG).d  # Remove dependency file

# Install to GNUstep system tools directory
install: $(PROG)
	@echo "Installing $(PROG) to $(GNUSTEP_SYSTEM_TOOLS)..."
	@install -d $(DESTDIR)$(GNUSTEP_SYSTEM_TOOLS)
	@install -m 755 $(PROG) $(DESTDIR)$(GNUSTEP_SYSTEM_TOOLS)/
	@echo "Installation complete!"
	@echo "$(PROG) installed to: $(GNUSTEP_SYSTEM_TOOLS)/$(PROG)"

# Uninstall
uninstall:
	@echo "Removing $(PROG) from $(GNUSTEP_SYSTEM_TOOLS)..."
	@rm -f $(GNUSTEP_SYSTEM_TOOLS)/$(PROG)
	@echo "Uninstallation complete!"

# Clean build artifacts
clean:
	rm -f $(PROG)
	rm -f *.o
	rm -f *.d  # Remove dependency files

.PHONY: all install uninstall clean
