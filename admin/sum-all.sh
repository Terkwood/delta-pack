#!/bin/bash

b2bsum beta-0.0.0.pck_to_beta-0.0.1.pck.diff > beta-0.0.0.pck_to_beta-0.0.1.pck.diff.b2bsum
b2bsum beta-0.0.1.pck_to_beta-0.0.2.pck.diff > beta-0.0.1.pck_to_beta-0.0.2.pck.diff.b2bsum
b2bsum beta-0.0.0.pck > beta-0.0.0.pck.b2bsum
b2bsum beta-0.0.1.pck > beta-0.0.1.pck.b2bsum
b2bsum beta-0.0.2.pck > beta-0.0.2.pck.b2bsum
