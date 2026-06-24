#!/bin/bash

wst=./core.wast
wtj=./core.json

wast2json "${wst}"
spectest-interp "${wtj}"
