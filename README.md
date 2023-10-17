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

You will receive access to Azure by using your company email address. However, you'll need to reset the password before first login.

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
