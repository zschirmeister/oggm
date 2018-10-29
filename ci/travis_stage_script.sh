#!/bin/bash
set -xe
cd "$(dirname "$0")/.."

export MPLBACKEND=agg

if [[ "$TRAVIS_OS_NAME" == "linux" ]]; then
    export IMAGE_TAG=latest
    test "$PYTHON_VERSION" = "3.7" && export IMAGE_TAG=py37 || true
    docker pull oggm/untested_base:$IMAGE_TAG

    mkdir -p $HOME/dl_cache
    export OGGM_DOWNLOAD_CACHE=/dl_cache

    docker create --name oggm_travis -ti -v $HOME/dl_cache:/dl_cache -e OGGM_DOWNLOAD_CACHE -e OGGM_TEST_ENV -e OGGM_TEST_MULTIPROC -e MPL -e CI -e TRAVIS -e TRAVIS_JOB_ID -e TRAVIS_BRANCH -e TRAVIS_PULL_REQUEST oggm/untested_base:$IMAGE_TAG /bin/bash /root/oggm/ci/travis_script.sh
    docker cp $PWD oggm_travis:/root/oggm

    docker start -ai oggm_travis

    docker rm oggm_travis || true
    exit 0
fi

if [[ "$TRAVIS_OS_NAME" == "windows" ]]; then
	wget -q https://repo.continuum.io/miniconda/Miniconda3-latest-Windows-x86_64.exe -O miniconda.exe
	chmod +x miniconda.exe
	./miniconda.exe "/InstallationType=JustMe" "/AddToPath=0" "/RegisterPython=0" "/NoRegistry=1" "/S" "/D=$(cygpath -w -a $HOME/miniconda)"
	rm miniconda.exe
elif [[ "$TRAVIS_OS_NAME" == "osx" ]]; then
	rvm get head || true
	wget -q https://repo.continuum.io/miniconda/Miniconda3-latest-MacOSX-x86_64.sh -O miniconda.sh
	bash miniconda.sh -b -p $HOME/miniconda
	rm miniconda.sh
else
    echo "Unsupported platform: $TRAVIS_OS_NAME"
    exit -1
fi

export PATH="$HOME/miniconda/bin:$PATH"

conda config --set always_yes yes --set changeps1 no
conda update -q conda
conda update -q --all
conda info -a
conda create -n oggm_env -c oggm -c conda-forge python="$PYTHON_VERSION"

source activate oggm_env

conda install -c oggm -c conda-forge oggm-deps pytest pytest-mpl
pip install -e .

pytest --mpl-upload $MPL --run-slow --run-test-env $OGGM_TEST_ENV oggm
