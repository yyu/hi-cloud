.PHONY: all

all: clean build
	@echo "\n--\n\n\033[36mRun me \033[0;37m$$ \033[0;1;32m__build__/hello\033[0m"

prebuild:
	mkdir -p __build__

build: prebuild
	# this should also work: (cd __build__; cmake -Daws-sdk-cpp_DIR=/opt/aws-sdk-cpp/__build__ ..; make)
	(cd __build__; cmake -DCMAKE_PREFIX_PATH=/opt/aws-sdk-cpp/__build__ ..; make)

clean:
	rm -rf __build__
