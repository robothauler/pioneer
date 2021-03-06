#!/c/msys64/usr/bin/bash -l

export PATH=/mingw64/bin:/c/Program\ Files\ \(x86\)/Inno\ Setup\ 5:$PATH

# Exit immediately upon error
set -e

# Echo the commands
set +v

mkdir -p /c/projects/pioneer/build
cd /c/projects/pioneer/build

cmake -G 'Unix Makefiles' \
	-DCMAKE_INSTALL_PREFIX="/c/Program Files/Pioneer" \
	-DPIONEER_DATA_DIR="/c/Program Files/Pioneer/data" \
	-DCMAKE_BUILD_TYPE:STRING=Release \
	-DGIT_EXECUTABLE=/c/Program\\ Files/Git/cmd/git.exe \
	-DPKG_CONFIG_EXECUTABLE=/mingw64/bin/pkg-config.exe \
	-DCMAKE_C_COMPILER=/mingw64/bin/x86_64-w64-mingw32-gcc.exe \
	-DCMAKE_CXX_COMPILER=/mingw64/bin/x86_64-w64-mingw32-g++.exe \
	-DUSE_SYSTEM_LIBGLEW=ON \
	-DUSE_SYSTEM_LIBLUA=OFF \
	/c/projects/pioneer

cmake --build . --target install

# Create the installer and upload artifact
ISCC pioneer.iss
appveyor PushArtifact ../pioneer-setup.exe
