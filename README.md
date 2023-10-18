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

4. You should know get a screen where you can choose between two accounts: "Cloud Labs DNS" and "Cloud Labs Workshop". Select "Cloud Labs Workshop", and click "Management console" to get access to your AWS account in your browser.

### Authenticating in the terminal

Access is set up using AWS Identity Center, and we'll use the single sign-on (SSO) way of authenticating, by running an interactive command to configure the environment.

1. Run `aws configure sso` and insert the following values in the interactive prompts (some inputs are empty, where we use the defaults):

    ```
    SSO session name (Recommended): cloud-labs-ws
    SSO start URL [None]: https://bekk-cloudlabs.awsapps.com/start
    SSO region [None]: eu-west-1
    SSO registration scopes [sso:account:access]:
    ```

2. A browser will open. Read the instructions in the terminal, and verify that the code is the same. After you've completed in the browser, you should see this output in the terminal:

    ```
    There are 2 AWS accounts available to you.
    Using the account ID 893160086441
    The only role available to you is: ManagedAdministratorAccess
    Using the role name "ManagedAdministratorAccess"
    ```

3. Then there's two more interactive inputs:

    ```
    CLI default client Region [None]: eu-west-1
    CLI default output format [None]:
    ```

4. We can use the CLI to call the Security Token Service (STS) and retrieve information about the current user. Run: `aws sts get-caller-identity --profile ManagedAdministratorAccess-893160086441`. You should get `UserId`, `Account` and `Arn` in the output.

## Terraform

TODO: Run `terraform apply` and verify outputs are correct.


## Frontend

We will use object storage to host our web site. The S3 resource in AWS can host file shares, queues, blobs and tables. Objects are organized into "Buckets". Each bucket can contain many Objects. An object can be a text file (HTML, javascript, txt), an image, a video or any other file. 

When serving a static web site from an S3 Bucket, we will need to enable the "Static Website" feature and allow for public access. We will also use terraform to upload the files in the `frontend_dist/` folder.

We use a CDN (Cloudfront) in front of the storage account to provide a custom domain for the frontend, and also ensure HTTPS traffic. The CDN has multiple settings for doing redirects, caching and more that we (mostly) won't touch in this workshop, but are should be looked at for production use cases.

1. Creating the S3 Bucket is straight forward. Add this to a new file, `frontend.tf`:

    ```terraform
    resource "aws_s3_bucket" "frontend" {
        bucket = local.domain_name
    }
    ```

This provisions up a S3 bucket that can store anything. For this to serve a static site, we need to enable static site hosting and public access to the objects in the bucket:

    ```terraform
    resource "aws_s3_bucket_website_configuration" "frontend" {
        bucket = aws_s3_bucket.frontend.id
        index_document {
            suffix = "index.html"
        }
    }

    resource "aws_s3_bucket_ownership_controls" "example" {
        bucket = aws_s3_bucket.frontend.id
        rule {
            object_ownership = "BucketOwnerPreferred"
        }
    }

    resource "aws_s3_bucket_public_access_block" "example" {
        bucket = aws_s3_bucket.frontend.id
        restrict_public_buckets = true
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
    }
    ```

    The code snippet also performs a regex search to look up the correct content type. The `filemd5` calculates a hash of the file content, which is used to determined whether a file need to be re-uploaded. Without the hash, terraform would not be able to detect a file change (only new/deleted/renamed files).

    We also need to make every object publicly available. This is the `acl` argument.

    After `terraform apply` is done, navigate to the S3 Resource in the AWS Console, find "Buckets" in the sidebar and select the bucket with your id. Verify that you see your files there.

    Navigate to "Properties" in the header, and find the endpoint at the bottom of the page. Copy it into a new tab in the browser, and verify that you get the "k6 demo todo frontend". Ignore the network error for now, that won't work before we've set up DNS properly.

4. We'll do the CDN configuration in one go:

    ```terraform
    resource "aws_cloudfront_distribution" "distribution" {
        enabled         = true
        is_ipv6_enabled = true

        origin {
            domain_name = aws_s3_bucket_website_configuration.frontend.website_endpoint
            origin_id   = aws_s3_bucket.frontend.bucket_regional_domain_name

            custom_origin_config {
                http_port                = 80
                https_port               = 443
                origin_keepalive_timeout = 5
                origin_protocol_policy   = "http-only"
                origin_read_timeout      = 30
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
            compress               = true
            allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
            cached_methods         = ["GET", "HEAD"]
            target_origin_id       = aws_s3_bucket.frontend.bucket_regional_domain_name
        }
    }
    ```

    This puts our website behind a CDN and also redirects all traffic to HTTPS.

5. Run `terraform apply`. This may take a while. When this is done, navigate to the Cloudfront resource in AWS and locate your distribution. Find your distribution domain name (`<something>.cloudfront.net`) in the details of the distribution, and copy it in a new tab to verify that the CDN serves the frontend correctly.