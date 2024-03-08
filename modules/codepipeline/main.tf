resource "aws_codepipeline" "terraform_pipeline" {

  name     = "${var.project_name}-pipeline"
  role_arn = var.codepipeline_role_arn
  tags     = var.tags

  artifact_store {
    location = var.s3_bucket_name
    type     = "S3"
    encryption_key {
      id   = var.kms_key_arn
      type = "KMS"
    }
  }

  stage {
    name = "Source"

    action {
      name             = "Download-Source"
      category         = "Source"
      owner            = "AWS"
      version          = "1"
      provider         = "CodeCommit"
      namespace        = "SourceVariables"
      output_artifacts = ["SourceOutput"]
      run_order        = 1

      configuration = {
        RepositoryName       = var.source_repo_name
        BranchName           = var.source_repo_branch
        PollForSourceChanges = "true"
      }
    }
  }

  dynamic "stage" {
    for_each = var.stages

    content {
      name = "Stage-${stage.value["name"]}"
      action {
        category         = stage.value["category"]
        name             = "Action-${stage.value["name"]}"
        owner            = stage.value["owner"]
        provider         = stage.value["provider"]
        input_artifacts  = [stage.value["input_artifacts"]]
        output_artifacts = [stage.value["output_artifacts"]]
        version          = "1"
        run_order        = index(var.stages, stage.value) + 2

        configuration = {
          ProjectName = stage.value["provider"] == "CodeBuild" ? "${var.project_name}-${stage.value["name"]}" : null
        }
      }
    }
  }

  stage {
    name = "Manual-approval-destroy"

    action {
      name     = "Manual-Approval-Destroy"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version  = "1"
      run_order = length(var.stages) + 1
    }
  }


  stage {
    name = "Stage-destroy"

    action {
      category         = "Build"
      name             = "Action-destroy"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["ApplyOutput"]
      output_artifacts = ["DestroyOutput"]
      version          = "1"
      run_order        = 2

      configuration = {
        ProjectName = "${var.project_name}-destroy"  
      }
    }
  }
}