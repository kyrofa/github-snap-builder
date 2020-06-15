from setuptools import setup, find_packages

setup(
    name="github-snap-builder",
    version="0.1.0",
    author="Kyle Fazzari",
    author_email="kyrofa@ubuntu.com",
    packages=find_packages("src"),
    package_dir={"": "src"},
    entry_points={"console_scripts": ["github-snap-builder=github_snap_builder._server:_main"]},
)
