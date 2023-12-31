# AWS workshop

An introductory workshop in AWS with Terraform

## Getting started

### Required tools

For this workshop you'll need:

* Git (terminal or GUI)
* [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
* [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)

* Your preferred terminal to run commands
* Your IDE of choice to edit Terraform files, e.g., VS Code with the Terraform plugin


On macOS, with `brew`, you can run `brew install awscli terraform`.

### Authenticating in the browser

You will receive access to AWS by using your company email address. However, you'll need to reset the password before first login.

1. Go to [https://bekk-cloudlabs.awsapps.com/start/](https://bekk-cloudlabs.awsapps.com/start/).

2. Enter your email address, and on the next screen click "Forgot password". Follow the steps to reset your password.

3. After setting your new password, go back to [https://bekk-cloudlabs.awsapps.com/start/](https://bekk-cloudlabs.awsapps.com/start/) and log in.

4. You should know get a screen where you can choose between two accounts: "Bekk Cloud Labs admin" and "Cloud Labs WS sandbox". Select "Cloud Labs WS sandbox", and click "Management console" to get access to your AWS account in your browser.

### Authenticating in the terminal

Access is set up using AWS Identity Center, and we'll use the single sign-on (SSO) way of authenticating, by running an interactive command to configure the environment. First we'll set up a SSO session, and then associate different AWS accounts with different profiles.

1. Run `aws configure sso-session`, and insert the following values:

    ```
    SSO session name: cloudlabs-common
    SSO start URL [None]: https://bekk-cloudlabs.awsapps.com/start
    SSO region [None]: eu-west-1
    SSO registration scopes [sso:account:access]:
    ```

2. Run `aws sso login --sso-session cloudlabs-common`. A browser will open. Read the instructions in the terminal, and verify that the code is the same.

  :bulb: If you're logged out during the workshop (typically a "No valid credential sources found" error), run the command again.

3. Now, we'll configure a *profile* that connects your session to a given AWS account. Run `aws configure sso --profile cloudlabs`:

    ```
    SSO session name (Recommended): cloudlabs-common
    There are 3 AWS accounts available to you.
    Using the account ID 893160086441
    The only role available to you is: ManagedAdministratorAccess
    Using the role name "ManagedAdministratorAccess"
    CLI default client Region [None]: eu-west-1
    CLI default output format [None]:
    ```

    This will setup a `cloudlabs` profile, using the `cloudlabs-common` session. Later, we'll add additional profiles using the same session.


4. We can use the CLI to call the Security Token Service (STS) and retrieve information about the current user. Run: `aws sts get-caller-identity --profile cloudlabs`. You should get `UserId`, `Account` and `Arn` in the output.

## Terraform

This repository has two folders for this workshop: `frontend_dist/` contains some pre-built frontend files that we'll upload and `infra/` will contain our terraform code. All files should be created here, and all terraform commands assume you're in this folder, unless something else is explicitly specified.

The `infra/` folder, does not contain many files yet:

* `terraform.tf` contains *provider* configuration. A provider is a plugin or library used by the terraform core to provide functionality. The `aws` we will use in this workshop provides the definition of AWS resources and translates to correct API requests when you apply your configuration.

Let's move on to running some actual commands 🚀

1. Before you can provision infrastructure, you have to initialize the providers from `terraform.tf`. You can do this by running `terraform init` (from the `infra/` folder!).

    This command will not do any infrastructure changes, but will create a `.terraform/` folder, a `.terraform.lock.hcl` lock file. The lock file can (and should) be committed. :warning: The `.terraform/` folder should not be committed, because it can contain secrets.

2. Create a `main.tf` file (in `infra/`) and add the following code, replacing `<yourid42>` with a random string containing only lowercase letters and numbers, no longer than 8 characters. The `id` is used to create unique resource names and subdomains, so ideally at least 6 characters should be used to avoid collisions.

    ```terraform
    locals {
      id = "<yourid42>"
    }
    ```

3. Take a look at at `terraform.tf`. 
    
    * The file declares some `data` blocks:
        * A `aws_vpc` block for the default VPC (Virtual Private Cloud) provisioned in every new AWS Account, which can be used to isolate resources in a virtual network.
        * A `aws_caller_identity` which contains information about the AWS identity used for running terraform, which we use in `output` blocks :point_down:
    * `output` blocks:
        * `user_arn`, which contains the [ARN](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference-arns.html) (Amazon Resource Name) of your user. ARNs are unambiguous across all of AWS.
        * `user_id` which is an IAM-specific (Identity and Access Management) [unique id](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_identifiers.html#identifiers-unique-ids)
    * `check` block:
        * `checks` are a [part of the Terraform language](https://developer.hashicorp.com/terraform/tutorials/configuration-language/checks) to validate infrastructure, and will output warnings if the `assert` fail. In this case, it verifies that you've set the `id` correctly in the previous step.

4. Run `terraform apply`. Confirm that you don't get a warning from the `check`, and take a look at the `user_arn` and `user_id` outputs.

## Database

We'll create a PostgreSQL database for our application. Amazon RDS can be used for MySQL, SQL Server, PostgresSQL and more. We'll simplify a little bit here, and create an AWS security group, with an ingress rule that allows traffic from the public internet. This is a *bad* idea for production databases.

1. First, we'll need to create a random password for our admin user. To generate the password, we'll generate a random string. Add the [Random provider](https://registry.terraform.io/providers/hashicorp/random/latest/docs) to the `required_providers` block in `terraform.tf`, followed by `terraform init` to initialize the provider.

    ```terraform
    random = {
      source = "hashicorp/random"
      version = "3.5.1"
    }
    ```

    Now, we can create a `random_password` resource to generate our password. Add the following code to `database.tf`:

    ```terraform
    resource "random_password" "postgres_password" {
      length  = 24
      special = false
    }
    ```

    This will create a random, 24-character password, which by default will contain uppercase, lowercase and numbers. We can reference the password by using the `result` attribute: `random_password.sql_server_admin_password.result`. This password will be stored in the terraform state file, and will not be regenerated every time `terraform apply` is run.

2.  We'll continue with the security group:

    ```terraform
    resource "aws_security_group" "db-allow-all" {
      name   = "security-group-todo-public-${local.id}"
      vpc_id = data.aws_vpc.default.id
    }

    resource "aws_vpc_security_group_ingress_rule" "db-allow-all" {
      security_group_id = aws_security_group.db-allow-all.id
      cidr_ipv4         = "0.0.0.0/0"
      from_port         = 5432
      to_port           = 5432
      ip_protocol       = "tcp"
    }
    ```

    This creates a security group, `security-group-todo-public-<yourid42>`, to the default VPC. Then an *ingress rule*, opening up for inbound traffic, is created for the security group. The inbound rule opens up TCP traffic from everywhere (`0.0.0.0/0`), on ports in the  `from_port` - `to_port`, in this case, only `5432`, the the default PostgreSQL port.

3. We'll continue by adding the actual database:

    ```terraform
    resource "aws_db_instance" "todo" {
      # The name of the instance
      identifier = "db-todo-${local.id}"
      # The name of the database
      db_name = "todo"

      # Credentials
      username = "todoadmin"
      password = random_password.postgres_password.result

      # Tier and scale configuration
      allocated_storage = 10
      instance_class    = "db.t3.micro"

      # Database type & version
      engine         = "postgres"
      engine_version = "15.3"

      # Make database accessible from the internet
      publicly_accessible    = true
      vpc_security_group_ids = [aws_security_group.db-allow-all.id]

      # Necessary to easily destroy after workshop, we don't want a backup snapshot when destroying
      skip_final_snapshot = true
    }
    ```

4. Add an `output` block to get the database host:

    ```terraform
    output "db_host" {
      value = aws_db_instance.todo.endpoint
    }
    ```

5. Run `terraform apply` and verify that everything works as intended. Go to the AWS console, and find the newly created resources. You should be able to find the security group, the database, and the setting that connects the security group to the database (on the RDS instance).

## Backend

The backend is a pre-built Docker image uploaded in the Elastic Container Registry (ECR). We'll run it using AWS App Runner which pulls the image and runs it as a container.

AWS App Runner is a fully managed application service that lets you build, deploy, and run web applications and API services without managing the underlying hardware. You can choose between building from source code or using an uploaded image from ECR, which is what we will do in this workshop. AWS App Runner does not support other registries at the time of writing.

1. Create a new file, `backend.tf` (still in `infra/`):

2. We'll create a new resource of type `aws_apprunner_service`, named `ar-todo-<yourid42>`.  Like this:

  ```terraform
  resource "aws_apprunner_service" "todo" {
    service_name = "ar-todo-${local.id}"

    # We get our source from an image
    source_configuration {
      image_repository {
        image_configuration {
          # App runs on port 3000
          port = "3000"
          # App expects a DATABASE_URL env variable
          runtime_environment_variables = {
            DATABASE_URL = "postgresql://${aws_db_instance.todo.username}:${random_password.postgres_password.result}@${aws_db_instance.todo.endpoint}/${aws_db_instance.todo.db_name}"
          }
        }
        // Image is pulled from a public ECR registry
        image_identifier      = "public.ecr.aws/m1p3r7y5/bekk-cloudlabs:latest"
        image_repository_type = "ECR_PUBLIC"
      }
      auto_deployments_enabled = false
    }
  }
  ```

  Note that the terraform local name (here: `todo`) does not need to be the same as the AWS service name `ar-todo-<yourid42>`.



3. Run `terraform apply`. By doing this the App Runner resource will be created and pull the image specified in the `image_identifier`. If `auto_deployments_enabled` is set to `true` App Runner will automatically deploy a new version when the image is updated. As we are not going to do code changes in the backend in this workshop, the auto-deployment is not necessary and is set to false.

4. Verify that the App Runner resource is created correctly in the AWS console (This may take several minutes). You might see that the App Runner resource appears in the AWS console for some time before the application is fully deployed and ready to use. 

5. Find the App Runner URL in the console, or by adding an `backend_url` `output` block printing `aws_apprunner_service.todo.service_url`. Navigate to `<url>/healtcheck` in your browser (or by using `curl` or equivalent) and verify that you get a message stating that the database connection is ok. The app is then running ok, and has correctly connected to the database.

## Frontend

We will use object storage to host our web site. The S3 resource in AWS can store virtually any kind of data (objects). Objects are organized into "Buckets". Each bucket can contain many Objects. An object can be a text file (HTML, javascript, txt), an image, a video or any other file. 

When serving a static web site from an S3 Bucket, we will need to enable the "Static Website" feature and allow for public access. We will also use terraform to upload the files in the `frontend_dist/` folder.

We use a CDN (Cloudfront) in front of the storage account to provide a custom domain for the frontend, and also ensure HTTPS traffic. The CDN has multiple settings for doing redirects, caching and more that we (mostly) won't touch in this workshop, but are should be looked at for production use cases.

1. Creating the S3 Bucket is straight forward. Add this to a new file, `frontend.tf`:

    ```terraform
    resource "aws_s3_bucket" "frontend" {
      bucket = "s3-bucket-${local.id}"
    }
    ```

    This provisions up a S3 bucket that can store anything. For us to add our frontend files to the bucket, we need to enable public object creation in the bucket and allow all accounts to upload objects.

    ```terraform
    resource "aws_s3_bucket_ownership_controls" "frontend" {
        bucket = aws_s3_bucket.frontend.id
        rule {
            object_ownership = "BucketOwnerPreferred"
        }
    }

    resource "aws_s3_bucket_public_access_block" "frontend" {
        bucket = aws_s3_bucket.frontend.id
        block_public_acls       = false
    }
    ```

2. To upload files, terraform must track the files in the `frontend_dist/` directory. We also need some MIME type information that is not readily available, so we will create a *map* that we can use to look up the types later. We will create local helper variables to help us out:

    ```terraform
    locals {
      frontend_dir   = "${path.module}/../frontend_dist"
      frontend_files = fileset(local.frontend_dir, "**")

      mime_types = {
        ".js"   = "application/javascript"
        ".html" = "text/html"
      }
    }
    ```

    `path.module` is the path to the `infra/` directory. `fileset(directory, pattern)` returns a list of all files in `directory` matching `pattern`.

3. Each file we want to upload is represented by a `aws_s3_object` resource. In order to create multiple resources, terraform provides a `for_each` meta-argument as a looping mechanism. We assign the `frontend_files` list to it, and can use `each.value` to refer to an element in the list.

    ```terraform
    resource "aws_s3_object" "file" {
        for_each = local.frontend_files

        bucket       = aws_s3_bucket.frontend.id
        key          = each.value
        source       = "${local.frontend_dir}/${each.value}"
        content_type = lookup(local.mime_types, regex("\\.[^.]+$", each.value), null)
        etag         = filemd5("${local.frontend_dir}/${each.value}")

        acl          = "public-read"

        # We can only provision objects with ACL after they are enabled on the bucket,
        # but there is still some eventual consistency, so it might still fail
        depends_on = [aws_s3_bucket_public_access_block.frontend]
    }
    ```

    The code snippet also performs a regex search to look up the correct content type. The `filemd5` calculates a hash of the file content, which is used to determined whether a file need to be re-uploaded. Without the hash, terraform would not be able to detect a file change (only new/deleted/renamed files).

    We also need to make every object publicly available. This is the `acl` argument.

    After `terraform apply` is done, navigate to the S3 Resource in the AWS Console, find "Buckets" in the sidebar and select the bucket with your id. Verify that you see your files there.

    <!-- TODO, confirm & create explanation
    Now that the files are uploaded to the bucket, you can disable public access. Remove the `aws_s3_bucket_ownership_controls` and `aws_s3_bucket_public_access_block` resources. -->

4. Now we need to enable static site hosting in the bucket. Add this to `frontend.tf`:

    ```terraform
     resource "aws_s3_bucket_website_configuration" "frontend" {
        bucket = aws_s3_bucket.frontend.id
        index_document {
            suffix = "index.html"
        }
    }
    ```

    Navigate to "Properties" in the header, and find the endpoint at the bottom of the page. Copy it into a new tab in the browser, and verify that you get the "k6 demo todo frontend". Ignore the network error for now, that won't work before we've set up DNS properly.

4. We'll do the CDN configuration in one go:

    ```terraform
    data "aws_cloudfront_cache_policy" "frontend" {
        name = "Managed-CachingDisabled"
    }
    
    resource "aws_cloudfront_distribution" "frontend" {
        enabled         = true
        is_ipv6_enabled = true

        origin {
            domain_name = aws_s3_bucket_website_configuration.frontend.website_endpoint
            origin_id   = aws_s3_bucket.frontend.bucket_regional_domain_name

            custom_origin_config {
                http_port              = 80
                https_port             = 443
                origin_protocol_policy = "http-only"
                origin_ssl_protocols = [
                    "TLSv1.2",
                ]
            }
        }

        viewer_certificate {
            cloudfront_default_certificate = true
        }

        restrictions {
            geo_restriction {
                restriction_type = "none"
                locations        = []
            }
        }

        default_cache_behavior {
            cache_policy_id        = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
            viewer_protocol_policy = "redirect-to-https"
            allowed_methods        = ["GET", "HEAD"]
            cached_methods         = ["GET", "HEAD"]
            target_origin_id       = aws_s3_bucket.frontend.bucket_regional_domain_name
        }
    }
    ```

    This puts our website behind a CDN and also redirects all traffic to HTTPS.

5. Run `terraform apply`. This may take a while. When this is done, navigate to the Cloudfront resource in AWS and locate your distribution. Find your distribution domain name (`<something>.cloudfront.net`) in the details of the distribution, and copy it in a new tab to verify that the CDN serves the frontend correctly.

## Backend DNS

Lets setup some DNS for our App Runner instance. DNS is managed by Route53. For this to work, we'll create an `aws_apprunner_custom_domain_associaton` terraform resource. This resource will configure the App Runner instance. In addtion, we need to create an `aws_route53_record` for a CNAME record. There are also mechanisms for validating DNS records that we will need to implement, where we will create some special DNS records requested by the App Runner instance.

The Route 53 hosted zone for `cloudlabs-aws.no` is managed in a separate account.

1. Go to [https://bekk-cloudlabs.awsapps.com/start#/](https://bekk-cloudlabs.awsapps.com/start#/) and choose "Bekk Cloud Labs admin", then "ManageDNSRecords" management console, you will get into the account managing Route 53. You can search for "Route 53" and find the hosted zone.

2. We want to provision records in this hosted zone with terraform, so we'll create a new profile in the CLI and use that to configure a separate AWS provider for this account. Similar to previous setup, run `aws configure sso --profile cloudlabs-dns`:

    ```
    SSO session name (Recommended): cloudlabs-common
    There are 3 AWS accounts available to you.
    Using the account ID 325039187874
    The only role available to you is: ManageDNSRecords
    Using the role name "ManageDNSRecords"
    CLI default client Region [None]: eu-west-1
    CLI default output format [None]:
    ```

    This will setup a `cloudlabs-dns` profile, using the `cloudlabs-common` session.

3. Then, add a new `provider` block to `terraform.tf`, below the previous one:

    ```terraform
    provider "aws" {
      alias = "ws-dns"
      # Must correspond to the AWS CLI configured profile name
      profile             = "cloudlabs-dns"
      region              = "eu-west-1"
      allowed_account_ids = ["325039187874"]
    }
    ```

    This will create a new, separate provider configuration that we can refer to using the alias "ws-dns".

4. Create new file, `dns.tf` and add a `data` block for the hosted DNS zone:

  ```terraform
  # Get the hosted zone from the admin account
  data "aws_route53_zone" "cloudlabs-aws-no" {
    # Note the use of the non-default provider!
    provider = aws.ws-dns

    name = "cloudlabs-aws.no."
  }
  ```
  

5. Then, let's configure App Runner and create the first CNAME record:

  ```terraform
  # Create a new variable for the API URL
  locals {
    api_url = "api.${local.id}.${data.aws_route53_zone.cloudlabs-aws-no.name}"
  }

  # Configure App Runner with new DNS name
  resource "aws_apprunner_custom_domain_association" "todo" {
    domain_name          = local.api_url
    service_arn          = aws_apprunner_service.todo.arn
    # This is an API, so we don't need the www subdomain
    enable_www_subdomain = false
  }

  # Setup the route53 record for App Runner
  resource "aws_route53_record" "backend" {
    # NB! Here we specify which provider we'll use
    provider        = aws.ws-dns

    allow_overwrite = true
    name            = local.api_url
    records         = [aws_apprunner_custom_domain_association.todo.dns_target]
    ttl             = 60
    type            = "CNAME"
    zone_id         = data.aws_route53_zone.cloudlabs-aws-no.zone_id
  }
  ```

6. Now, we'll need to create some validation records. We know that that there will be two, so we'll use `count = 2` to iterate over them. You can read more about [count in the documentation](https://developer.hashicorp.com/terraform/language/meta-arguments/count).

  ```terraform
  # Create local variable to simplify and avoid duplication
  locals {
    validation_records = tolist(aws_apprunner_custom_domain_association.todo.certificate_validation_records)
  }

  resource "aws_route53_record" "backend_validation_records" {
    // We know there are two records, so using this because for_each with "unknown" number of values gives an error or requires targeted deploy
    count = 2

    provider        = aws.ws-dns
    allow_overwrite = true
    name            = local.validation_records[count.index].name
    records = [
      local.validation_records[count.index].value
    ]
    ttl     = 60
    type    = local.validation_records[count.index].type
    zone_id = data.aws_route53_zone.cloudlabs-aws-no.zone_id
  }
  ```

7. Run `terraform apply` and go check out your App Runner instance. Find the certificate setup under the "Custom domains" tab. Also validate that `https://api.<yourid42>.cloublabs-aws.no/healthcheck` gives a postive response.


## Frontend DNS

Now, we'll do something similar for the frontend. This time, we'll have to create an A record, and also have to create our own certificate and do the validation differently. For the certificate to work with CloudFront, it must be created in the same account, but in the `us-east-1` region.

1. Add a new provider for creating the certficiate, using the original profile (`cloudlabs`), but a different region:

  ```terraform
  provider "aws" {
    alias = "ws-acm"
    # Must correspond to the AWS CLI configured profile name
    profile             = "cloudlabs"
    region              = "us-east-1"
    allowed_account_ids = ["893160086441"]
  }
  ```

2. We'll start by creating the record and the certificate:

  ```terraform
  # The record that will point to the CloudFront distribution
  resource "aws_route53_record" "frontend" {
    provider = aws.ws-dns

    zone_id = data.aws_route53_zone.cloudlabs-aws-no.zone_id
    name    = "${local.id}.${data.aws_route53_zone.cloudlabs-aws-no.name}"
    type    = "A"
    alias {
      name                   = aws_cloudfront_distribution.frontend.domain_name
      zone_id                = aws_cloudfront_distribution.frontend.hosted_zone_id
      evaluate_target_health = false
    }
  }

  # The certificate
  resource "aws_acm_certificate" "frontend" {
    provider          = aws.ws-acm
    domain_name       = "${local.id}.${data.aws_route53_zone.cloudlabs-aws-no.name}"
    validation_method = "DNS"
  }
  ```

3. Then we'll create the validation records, and `aws_acm_certificate_validation` which doesn't actually create anything but helps requesting DNS validation. See [the documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation) for more information.

  ```terraform
  # The validation records
  resource "aws_route53_record" "frontend-validation" {
    provider = aws.ws-dns
    zone_id  = data.aws_route53_zone.cloudlabs-aws-no.zone_id
    name     = one(aws_acm_certificate.frontend.domain_validation_options).resource_record_name
    type     = one(aws_acm_certificate.frontend.domain_validation_options).resource_record_type
    records  = [one(aws_acm_certificate.frontend.domain_validation_options).resource_record_value]
    ttl      = 60
  }

  # Pseudo-resource used to help validation in terraform, see docs
  resource "aws_acm_certificate_validation" "frontend" {
    provider                = aws.ws-acm
    certificate_arn         = aws_acm_certificate.frontend.arn
    validation_record_fqdns = [aws_route53_record.frontend-validation.fqdn]
  }
  ```

4. We also need to update our CloudFront configuration to support the custom domain name. First, we'll add our custom domain as an alias, then we'll update with our custom certificate:

    ```terraform
    resource "aws_cloudfront_distribution" "frontend" {
        // Other properties ...

        // Add an alias to the custom domain
        aliases = ["${local.id}.${data.aws_route53_zone.cloudlabs-aws-no.name}"]

        // Modify the viewer_certificate block
        viewer_certificate {
          //cloudfront_default_certificate = true // <-- Remove this
          acm_certificate_arn = aws_acm_certificate_validation.frontend.certificate_arn
          ssl_support_method  = "sni-only"
        }

        // Other properties ...
    }
    ```

5. Go to `https://<yourid42>.cloudlabs-aws.no` and verify that you get a successful response. The propagation of the certificate can take some time, but you can look at the status if you navigate to the CloudFront resource in the AWS console.


## Extra tasks

Ask your workshop facilitator!
