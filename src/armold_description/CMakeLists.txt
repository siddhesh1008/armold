cmake_minimum_required(VERSION 3.8)
project(armold_description)

find_package(ament_cmake REQUIRED)

# meshes/ is installed even though its contents are git-ignored: a user who has
# purchased the design drops the STLs in and they are packaged from there.
install(
  DIRECTORY urdf launch rviz config meshes
  DESTINATION share/${PROJECT_NAME}
)

ament_package()
