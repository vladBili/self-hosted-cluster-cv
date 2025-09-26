#!/bin/bash
sudo systemctl daemon-reload
sudo systemctl enable kubeadm-join.service
sudo systemctl start kubeadm-join.service
