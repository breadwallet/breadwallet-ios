#!/bin/bash
# Compiles protobuf schema to Swift
protoc --swift_out=. Messages.proto
