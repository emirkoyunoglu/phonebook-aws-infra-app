# phonebook-aws-infra-app

This project is designed to automatically deploy a simple phonebook web application (Python/Flask and MySQL) using Terraform and Ansible.

## Project Structure

The project consists of the following main components:

- **Terraform:** Used to provision the infrastructure (servers, database, load balancer, etc.). Located in the `terraform-files/` directory.
- **Ansible:** Used to deploy and configure the phonebook application on the provisioned infrastructure. Located in the `project/` directory.
- **Phonebook Application:** A simple web application based on Python Flask. Located in the `project/phonebook/` directory.
- **Ansible Roles:** Provide modular tasks for deploying and configuring different components of the application (web server, database, ALB switch). Located in the `project/roles/` directory.

## Setup and Usage

Follow these steps to set up and run this project:

### Prerequisites

- [Terraform](https://www.terraform.io/downloads) must be installed.
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/index.html) must be installed.
- Python and pip must be installed.
- CLI tools and authentication configuration for the cloud provider being used (AWS, Azure, GCP, etc.) must be set up. (Depending on the provider used in your Terraform files)

### Steps

1.  **Clone the Project:**

    ```bash
    git clone <your_repository_url>
    cd <repository_folder>
    ```

2.  **Provision Infrastructure with Terraform:**

    Navigate to the `terraform-files/` directory:

    ```bash
    cd terraform-files/
    ```

    Initialize Terraform:

    ```bash
    terraform init
    ```

    Review the infrastructure plan (optional):

    ```bash
    terraform plan
    ```

    Create the infrastructure:

    ```bash
    terraform apply
    ```

    Once completed, the Terraform output will provide necessary information for Ansible (server IPs, etc.). Note this information.

3.  **Configure Ansible Inventory:**

    Update your inventory in the relevant files in the `project/group_vars/servers.yml` and `project/host_vars/` directories using the server information obtained from the Terraform output.

    For example, you can edit the `project/group_vars/servers.yml` file.

4.  **Deploy the Application with Ansible:**

    Return to the project root directory:

    ```bash
    cd ../project/
    ```

    Run the Ansible playbook:

    ```bash
    ansible-playbook playbook.yml
    ```

    This command will configure the web server, database, and ALB switch, and deploy the phonebook application.

5.  **Access the Application:**

    After deployment is complete, you can access the phonebook application by navigating to the public IP address/DNS name of the ALB or web server in your web browser.

## Cleanup

To remove the created infrastructure, run the following command in the `terraform-files/` directory:

```bash
cd terraform-files/
terraform destroy
```

This command will delete all resources provisioned by Terraform.