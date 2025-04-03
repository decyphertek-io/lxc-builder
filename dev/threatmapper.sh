# Integrated solution for automated CIS compliance remediation with rollback capability

# 1. Create a wrapper script that connects Prowler/ThreatMapper with Cloud Custodian
cat > /home/adminotaur/Documents/git/custodian/tools/compliance-runner.py << 'EOF'
#!/usr/bin/env python3
import argparse
import json
import subprocess
import logging
import datetime
import os
import time

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler("/var/log/custodian-compliance.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger("compliance-runner")

def create_backup(project_id):
    """Create backup of resource state before making changes"""
    timestamp = datetime.datetime.now().strftime("%Y%m%d%H%M%S")
    backup_dir = f"/home/adminotaur/Documents/git/custodian/backups/{project_id}_{timestamp}"
    os.makedirs(backup_dir, exist_ok=True)
    
    logger.info(f"Creating backup in {backup_dir}")
    
    # Backup key resources using gcloud export
    resources = ["compute", "storage", "sql", "bigquery", "iam", "kms"]
    for resource in resources:
        try:
            subprocess.run(
                f"gcloud {resource} export --project={project_id} > {backup_dir}/{resource}.json",
                shell=True, check=True
            )
            logger.info(f"Backed up {resource} configuration")
        except subprocess.CalledProcessError as e:
            logger.error(f"Failed to backup {resource}: {str(e)}")
    
    return backup_dir

def run_assessment(tool, project_id):
    """Run assessment using Prowler or ThreatMapper"""
    logger.info(f"Running assessment with {tool} on project {project_id}")
    
    if tool.lower() == "prowler":
        cmd = f"prowler gcp --project-id {project_id} -v -M csv -F prowler_assessment"
    else:  # ThreatMapper
        cmd = f"threatmapper scan gcp --project-id {project_id} --output-file threatmapper_assessment.json"
    
    try:
        subprocess.run(cmd, shell=True, check=True)
        logger.info(f"{tool} assessment completed successfully")
        return True
    except subprocess.CalledProcessError as e:
        logger.error(f"{tool} assessment failed: {str(e)}")
        return False

def run_cloud_custodian(project_id, policies_dir):
    """Run Cloud Custodian policies for remediation"""
    logger.info(f"Running Cloud Custodian remediation on project {project_id}")
    
    # Get all policy files
    policy_files = []
    for root, _, files in os.walk(policies_dir):
        for file in files:
            if file.endswith('.yml'):
                policy_files.append(os.path.join(root, file))
    
    success_count = 0
    total_policies = len(policy_files)
    
    for policy_file in policy_files:
        try:
            logger.info(f"Applying policy: {policy_file}")
            subprocess.run(
                f"custodian run --output-dir=/var/log/custodian/{project_id} {policy_file} --resource-types gcp",
                shell=True, check=True, env=dict(os.environ, GOOGLE_CLOUD_PROJECT=project_id)
            )
            success_count += 1
        except subprocess.CalledProcessError as e:
            logger.error(f"Policy application failed for {policy_file}: {str(e)}")
    
    success_rate = (success_count / total_policies) * 100
    logger.info(f"Completed reme