"""Display the Armold arm in RViz.

    ros2 launch armold_description display.launch.py

Starts robot_state_publisher over the xacro-expanded URDF, the joint slider GUI,
and RViz preloaded with the Armold config.
"""

from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.conditions import IfCondition
from launch.substitutions import Command, LaunchConfiguration, PathJoinSubstitution
from launch_ros.actions import Node
from launch_ros.parameter_descriptions import ParameterValue
from launch_ros.substitutions import FindPackageShare


def generate_launch_description():
    pkg = FindPackageShare("armold_description")

    model = PathJoinSubstitution([pkg, "urdf", "armold.urdf.xacro"])
    rviz_config = PathJoinSubstitution([pkg, "rviz", "armold.rviz"])

    # ParameterValue(..., value_type=str) matters: without it the expanded URDF
    # is parsed as YAML and a plain string is not what robot_state_publisher wants.
    robot_description = ParameterValue(
        Command(["xacro ", model]), value_type=str
    )

    return LaunchDescription([
        DeclareLaunchArgument(
            "gui", default_value="true",
            description="Start joint_state_publisher_gui with its sliders.",
        ),
        DeclareLaunchArgument(
            "rviz", default_value="true",
            description="Start RViz.",
        ),

        Node(
            package="robot_state_publisher",
            executable="robot_state_publisher",
            output="screen",
            parameters=[{"robot_description": robot_description}],
        ),

        Node(
            package="joint_state_publisher_gui",
            executable="joint_state_publisher_gui",
            condition=IfCondition(LaunchConfiguration("gui")),
        ),

        Node(
            package="rviz2",
            executable="rviz2",
            output="screen",
            arguments=["-d", rviz_config],
            condition=IfCondition(LaunchConfiguration("rviz")),
        ),
    ])
