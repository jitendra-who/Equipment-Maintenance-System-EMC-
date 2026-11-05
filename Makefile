CXX      ?= g++
CXXFLAGS ?= -std=c++17 -Wall -Wextra -O2
CXXFLAGS += -Iinclude

SRC = src/main.cpp src/Plant.cpp src/PlantGraph.cpp src/Scheduler.cpp src/Simulator.cpp src/Menu.cpp

all: iefms

iefms: $(SRC) $(wildcard include/*.h)
	$(CXX) $(CXXFLAGS) -o $@ $(SRC)

run: iefms
	./iefms

simulate: iefms
	./iefms --simulate

test: tests/test_core.cpp src/PlantGraph.cpp
	$(CXX) $(CXXFLAGS) -O0 -o run_tests tests/test_core.cpp src/PlantGraph.cpp
	./run_tests

clean:
	rm -f iefms iefms.exe run_tests run_tests.exe

.PHONY: all run simulate test clean
