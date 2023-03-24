#!/bin/bash
DATA_DIR=/data/
BACKUP_DIR=/data/backups
sudo rm -fr $BACKUP_DIR/*
sudo ./backup.sh -dir $DATA_DIR -rf $BACKUP_DIR

