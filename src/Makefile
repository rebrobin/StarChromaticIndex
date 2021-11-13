
Optimization=-O3

PROGRAM=star_precolor

all: $(PROGRAM)

$(PROGRAM): $(PROGRAM).cpp
	g++ $(Optimization) -o $(PROGRAM) $(PROGRAM).cpp

oldgcc:  $(PROGRAM).cpp
	g++ $(Optimization) -std=c++11 -o $(PROGRAM)_oldgcc $(PROGRAM).cpp

clean:
	rm -f $(PROGRAM)
