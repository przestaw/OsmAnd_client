#!/bin/bash

git clone https://github.com/przestaw/OsmAnd_client.git OsmAnd-submodules
pushd OsmAnd-submodules
git submodule init
git submodule update --depth 1

# rm
rm -Rf android/OsmAnd-java/libs/*.jar
rm -Rf android/OsmAnd/libs/*.jar
rm -Rf android/OsmAnd-telegram/
rm -Rf resources/icons/tools/SVGtoXML/vd-tool
popd

echo 'Proceed as described in the README.'
