<<<<<<< HEAD

=======
#!/bin/bash

# Fixed script to run Yosys synthesis for ReLU design

echo "=== Starting ReLU Design Synthesis (Fixed Version) ==="

# Create a log file
yosys -q synth_fixed.ys > yosys.log 2>&1

# Check if synthesis was successful
if [ $? -eq 0 ]; then
    echo "Synthesis completed successfully!"
    echo "Generated files:"
    ls -l relu_synth.v
    
    # Generate statistics
    echo ""
    echo "=== Design Statistics ==="
    grep -A 20 "=== relu ===" yosys.log
    
    # Generate schematic if dot is available
    if command -v dot &> /dev/null; then
        echo ""
        echo "Generating schematic PDF..."
        dot -Tpdf relu_synth.dot -o relu_synth.pdf
        echo "Schematic saved to relu_synth.pdf"
    fi
else
    echo "Synthesis failed. Check yosys.log for details."
    exit 1
fi

echo "=== Synthesis Complete ==="
>>>>>>> new-content