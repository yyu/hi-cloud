# minimal CMakeLists.txt for the AWS SDK for C++
cmake_minimum_required(VERSION 3.2)

project(hello-aws)

# Locate the AWS SDK for C++ package.
# Requires that you build with:
#   -DCMAKE_PREFIX_PATH=/path/to/aws-sdk-cpp/__build__/
find_package(AWSSDK REQUIRED COMPONENTS polly)

# The executable name and its sourcefiles
add_executable(hello hello.cpp)

# The libraries used by your executable.
target_link_libraries(hello ${AWSSDK_LINK_LIBRARIES})
