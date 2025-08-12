<<<<<<< HEAD

=======
# Makefile for ReLU synthesis

.PHONY: synth clean

# Default target
synth:
	@echo "Running Yosys synthesis for ReLU design..."
	yosys -q synth.ys
	@echo "Synthesis completed. Results in relu_synth.v"

# Generate dot schematic to PDF (if graphviz is installed)
schematic: synth
	@echo "Generating schematic PDF..."
	dot -Tpdf relu_synth.dot -o relu_synth.pdf

# Clean up generated files
clean:
	rm -f relu_synth.v relu_synth.dot relu_synth.pdf

# View detailed statistics
report: synth
	@echo "Circuit Statistics:"
	grep -A 20 "=== relu ===" yosys.log
>>>>>>> new-content