#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: Workflow
label: FINRISK - Heart Failure and Microbiome (9615015) Evaluation
doc: >
  BRIEF DESCRIPTION ABOUT THE CHALLENGE, e.g.
  This workflow will run and evaluate singularity submissions to the
  FINRISK - Heart Failure and Microbiome (syn27130803). Metrics returned are harrell_c,hoslem_test.

requirements:
  - class: StepInputExpressionRequirement

inputs:
  adminUploadSynId:
    label: Synapse Folder ID accessible by an admin
    type: string
  submissionId:
    label: Submission ID
    type: int
  submitterUploadSynId:
    label: Synapse Folder ID accessible by the submitter
    type: string
  synapseConfig:
    label: filepath to .synapseConfig file
    type: File
  workflowSynapseId:
    label: Synapse File ID that links to the workflow
    type: string
  workingDir:
    label: file to working directory that contain the input file
    type: string

outputs: {}

steps:

##?can we skip this step because it already authenticate, or can we add something like syn #= synapseclient.login()
  set_submitter_folder_permissions:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.1/cwl/set_permissions.cwl
    in:
      - id: entityid
        source: "#submitterUploadSynId"
      # TODO: replace `valueFrom` with the admin user ID or admin team ID
      - id: principalid
        valueFrom: "3379097"
      - id: permissions
        valueFrom: "download"
      - id: synapse_config
        source: "#synapseConfig"
    out: []

##?can we skip this step?
  set_admin_folder_permissions:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.1/cwl/set_permissions.cwl
    in:
      - id: entityid
        source: "#adminUploadSynId"
      # TODO: replace `valueFrom` with the admin user ID or admin team ID
      - id: principalid
        valueFrom: "3379097"
      - id: permissions
        valueFrom: "download"
      - id: synapse_config
        source: "#synapseConfig"
    out: []

##?modify
  get_singularity_submission:
    run: get_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: synapse_config
        source: "#synapseConfig"
    out:
      - id: filepath
      - id: entity_id
      - id: entity_type
      - id: results

##?modify?, invalid if the suffix other than .sif or zip. Or maybe can skip this part
  email_validation:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.1/cwl/validate_email.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: synapse_config
        source: "#synapseConfig"
      - id: status
        source: "#validate_docker/status"
      - id: invalid_reasons
        source: "#validate_docker/invalid_reasons"
      # OPTIONAL: set `default` to `false` if email notification about valid submission is needed
      - id: errors_only
        default: true
    out: [finished]

  ##?skip unecessary in this framework
  annotate_validation_with_output:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.1/cwl/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: annotation_values
        source: "#validate_docker/results"
      - id: to_public
        default: true
      - id: force
        default: true
      - id: synapse_config
        source: "#synapseConfig"
    out: [finished]

  ##?skip unnecessary
  check_docker_status:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.1/cwl/check_status.cwl
    in:
      - id: status
        source: "#validate_docker/status"
      - id: previous_annotation_finished
        source: "#annotate_docker_validation_with_output/finished"
      - id: previous_email_finished
        source: "#email_docker_validation/finished"
    out: [finished]

  ##?any idea
  run_singularity_submission:

  run_docker:
    run: steps/run_docker.cwl
    in:
      - id: docker_repository
        source: "#get_docker_submission/docker_repository"
      - id: docker_digest
        source: "#get_docker_submission/docker_digest"
      - id: submissionid
        source: "#submissionId"
      - id: docker_registry
        source: "#get_docker_config/docker_registry"
      - id: docker_authentication
        source: "#get_docker_config/docker_authentication"
      - id: status
        source: "#validate_docker/status"
      - id: parentid
        source: "#submitterUploadSynId"
      - id: synapse_config
        source: "#synapseConfig"
      # OPTIONAL: set `default` to `false` if log file should not be uploaded to Synapse
      - id: store
        default: true
      # TODO: replace `valueFrom` with the absolute path to the data directory to be mounted
      - id: input_dir
        valueFrom: "/tmp"
      - id: docker_script
        default:
          class: File
          location: "run_docker.py"
    out:
      - id: predictions

##?not sure if I need this, but if I gonna upload score.csv and stats.csv somewhere?
  upload_results:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.1/cwl/upload_to_synapse.cwl
    in:
      - id: infile
        source: "#run_docker/predictions"
      - id: parentid
        source: "#adminUploadSynId"
      - id: used_entity
        source: "#get_docker_submission/entity_id"
      - id: executed_entity
        source: "#workflowSynapseId"
      - id: synapse_config
        source: "#synapseConfig"
    out:
      - id: uploaded_fileid
      - id: uploaded_file_version
      - id: results
##?move this step after score
  annotate_upload_results:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.1/cwl/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: annotation_values
        source: "#upload_results/results"
      - id: to_public
        default: true
      - id: force
        default: true
      - id: synapse_config
        source: "#synapseConfig"
      - id: previous_annotation_finished
        source: "#annotate_docker_validation_with_output/finished"
    out: [finished]

  validate:
    run: steps/validate.cwl
    in:
      - id: input_file
        source: "#run_docker/predictions"
      - id: entity_type
        source: "#get_docker_submission/entity_type"
    out:
      - id: results
      - id: status
      - id: invalid_reasons
  
  email_validation:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.1/cwl/validate_email.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: synapse_config
        source: "#synapseConfig"
      - id: status
        source: "#validate/status"
      - id: invalid_reasons
        source: "#validate/invalid_reasons"
      # OPTIONAL: set `default` to `false` if email notification about valid submission is needed
      - id: errors_only
        default: true
    out: [finished]

  annotate_validation_with_output:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.1/cwl/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: annotation_values
        source: "#validate/results"
      - id: to_public
        default: true
      - id: force
        default: true
      - id: synapse_config
        source: "#synapseConfig"
      - id: previous_annotation_finished
        source: "#annotate_docker_upload_results/finished"
    out: [finished]

  check_status:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.1/cwl/check_status.cwl
    in:
      - id: status
        source: "#validate/status"
      - id: previous_annotation_finished
        source: "#annotate_validation_with_output/finished"
      - id: previous_email_finished
        source: "#email_validation/finished"
    out: [finished]

  score:
    run: steps/score.cwl
    in:
      - id: input_file
        source: "#run_docker/predictions"
      - id: goldstandard
        source: "#download_goldstandard/filepath"
      - id: check_validation_finished 
        source: "#check_status/finished"
    out:
      - id: results
      
  email_score:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.1/cwl/score_email.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: synapse_config
        source: "#synapseConfig"
      - id: results
        source: "#score/results"
      # OPTIONAL: add annotations to be withheld from participants to `[]`
      # - id: private_annotations
      #   default: []
    out: []

  annotate_submission_with_output:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.1/cwl/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: annotation_values
        source: "#score/results"
      - id: to_public
        default: true
      - id: force
        default: true
      - id: synapse_config
        source: "#synapseConfig"
      - id: previous_annotation_finished
        source: "#annotate_validation_with_output/finished"
    out: [finished]
 