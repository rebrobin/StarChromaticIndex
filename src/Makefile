
PROGRAM=star_precolor

Optimization=-O3

all: $(PROGRAM) $(PROGRAM)128

$(PROGRAM): $(PROGRAM).cpp
	g++ $(Optimization) -o $(PROGRAM) $(PROGRAM).cpp

# We use a macro to indicate whether we should use 128 bits for bit masks.
# Since this is simulated with two 64-bit words on 64-bit machines, it's slower than 64-bit masks.
# We compile the 128-bit version to a separate executable.
$(PROGRAM)128: $(PROGRAM).cpp
	g++ $(Optimization) -D USE128BITS=yes -o $(PROGRAM)128 $(PROGRAM).cpp

oldgcc:  $(PROGRAM).cpp
	g++ $(Optimization) -std=c++11 -o $(PROGRAM)_oldgcc $(PROGRAM).cpp

oldgcc128:  $(PROGRAM).cpp
	g++ $(Optimization) -std=c++11 -D USE128BITS=yes -o $(PROGRAM)128_oldgcc $(PROGRAM).cpp

clean:
	rm -f $(PROGRAM)
