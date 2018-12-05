# Makefile for building this docker image
# Author: Christiam Camacho (camacho@ncbi.nlm.nih.gov)
# Created: Wed 05 Dec 2018 04:33:34 PM EST

SHELL=/bin/bash
.PHONY: build check clean

USERNAME?=ncbi
IMG=makeblastdb4cloud

build:
	docker build -t ${USERNAME}/${IMG} .

clean:
	docker image rm ${USERNAME}/${IMG}
