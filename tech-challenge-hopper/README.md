# README

TODO!

For dev work on Hopper itself:
- Clone repo -> linux (Ubuntu) environment
- Copy env-vars-template -> env-vars; enter values
- Use a valid AWS profile name to launch the container - TODO: add example
- Use ./hopper.sh create/destroy to build/run local image the same way it would be pulled and used OR ...
- Use ./debug.sh to build/run local image and start in container shell

---

# EVERYTHING BELOW IS FROM ESIS SUBMISSION FOR REFERENCE - IT WILL BE REMOVED

![KYC Advisors logo-20220922-03](https://user-images.githubusercontent.com/66387533/192112996-483eae0a-d1f2-4364-96a8-893c4280be26.png)
# Instructions for Deploying the solution in an AWS Account 
This is the main README.md file that contains all the instructions for Team KYC's submitted solution for the USCIS ESIS code challenge.

Self evaluation criteria excel file is [here](https://github.com/kyc-esis-tech-challenge/automation-runtime/blob/main/DHS%20USCIS%20ESIS%20-%20Code%20Submission%20-%20Evaluation%20Matrix.xlsx)

## High level Solution diagram  
![ESIS high level solution architecture](https://user-images.githubusercontent.com/66387533/192619252-d3d4f9db-64ca-4455-98f3-8c21808467dc.jpg)

# Deployment and execution steps for Evaluators 
There are 3 ways to automatically deploy this solution and execute.
- Option 1: GitPod (Easiest) - Evaluator doing everything from 1 browser tab (pre-requisite is a web browser)
- Option 2: macOS - Evaluator running the scripts on a macbook (pre-requisites are docker, git and terminal command line knowledge)
- Option 3: Windows - Evaluator running the scripts on a Windows machine (pre-requisites are docker, git and powershell command line knowledge)

<details>
  <summary>Option 1: GitPod deployment and execution steps for Evaluators</summary>

- Login to GitHub using the `esis-uscis-evaluator` user. If you use another account you have another step to authorize GitPod with your GitHub user.  This has already been done for the `esis-uscis-evaluator` GitHub user
- Right click on the 'Open in GitPod' button below and open in a new browser tab

  [![Open in Gitpod](https://gitpod.io/button/open-in-gitpod.svg)](https://gitpod.io/#https://github.com/kyc-esis-tech-challenge/automation-runtime)
  
- Once the window loads you will see VS code in the browser
- Update the environment variable configuration file `env-vars-template` (see screenshot below)
  - Update lines 1 and 2 with the the AWS account access key and secret access key from the email sent to ESIS-EVAL@uscis.dhs.gov
  - Update lines 3 and 4 with the the Github credentials (username: esis-uscis-evaluator, personal access token in email) from the email sent to ESIS-EVAL@uscis.gov 
  
  ![ESIS gitpod env var](https://user-images.githubusercontent.com/66387533/192423893-afbad8e2-9d41-4c82-9fd1-781f4d4bb18d.png)

- Go to the terminal section of VS code at the bottom of the screen and follow the rest of the instructions below
<br><br>
>GitHub registry login
- Log into the GitHub container registry using the `esis-uscis-evaluator` user to pull down the executable docker image which will run the infrastructure environment launch script, teardown script and data processing pipeline. You can find the GitHub password (personal access token) for the `esis-uscis-evaluator` user in the email sent to ESIS-EVAL@uscis.dhs.gov 
  - Open a terminal window and type in:
      - `docker login ghcr.io --username esis-uscis-evaluator --password <GitHub personal access token>`
<br><br>
>Execute the environment launch setup script (100% automated)
- Run the following docker command from a terminal to deploy the entire infrastructure to AWS.  The first time you run this will pull down the executable docker image for running the scripts.  The docker image size is ~1.5GB  
  - `docker run --rm -tiv $(pwd)/runtime:/esis/runtime --env-file env-vars-template ghcr.io/kyc-esis-tech-challenge/automation-build:main create `
<br><br>
>Execute the data processing pipeline to ingest data to kafka  (100% automated)
- Run the following docker command from a terminal  
  - `docker run --rm -tiv $(pwd)/runtime:/esis/runtime --env-file env-vars-template ghcr.io/kyc-esis-tech-challenge/automation-build:main load-data`
  - Projected data ingestion time to the Aurora PostgreSQL destination db is ~20 min
<br><br>
>Log into the pharmacy web app 
- See “Instructions on how to access the Production Solution and other tools”
- Execute use cases 14 and 15 (from the code submission document) in the web app 
<br><br>
>Execute the environment teardown script  (100% automated)
- Run the following docker command from a terminal  
  - `docker run --rm -tiv $(pwd)/runtime:/esis/runtime --env-file env-vars-template ghcr.io/kyc-esis-tech-challenge/automation-build:main destroy`
  
</details>

<details>
  <summary>Option 2: macOS deployment and execution steps for Evaluators</summary>
  
> Steps to configure your local machine to execute the single 100% automated infrastructure environment launch script
- Install Docker Desktop on your local machine. For instructions on how to do this see this link <https://docs.docker.com/get-started/>
- Start Docker Desktop
- Clone this `automation-runtime` repository to a local directory that does NOT have spaces in the path name
- Open a terminal window and CD to the cloned `automation-runtime` directory 
- Update the environment variable configuration file `env-vars-template` in the cloned local directory 
  - Update lines 1 and 2 with the AWS account access key and secret access key from the email sent to ESIS-EVAL@uscis.dhs.gov 
  - Update lines 3 and 4 with the Github credentials (username: esis-uscis-evaluator, personal access token in email) from the email sent to ESIS-EVAL@uscis.gov 
- Log into the GitHub container registry using the `esis-uscis-evaluator` user to pull down the executable docker image which will run the infrastructure environment launch script, teardown script and data processing pipeline. You can find the GitHub password (personal access token) for the `esis-uscis-evaluator` user in the email sent to ESIS-EVAL@uscis.dhs.gov 
  - Open a terminal window and type in:
      - `docker login ghcr.io --username esis-uscis-evaluator --password <GitHub personal access token>`
<br><br>
>Execute the environment launch setup script (100% automated)
- Run the following docker command from a terminal to deploy the entire infrastructure to AWS.  The first time you run this will pull down the executable docker image for running the scripts.  The docker image size is ~1.5GB  
  - `docker run --rm -tiv $(pwd)/runtime:/esis/runtime --env-file env-vars-template ghcr.io/kyc-esis-tech-challenge/automation-build:main create `
<br><br>
>Execute the data processing pipeline to ingest data to kafka  (100% automated)
- Run the following docker command from a terminal  
  - `docker run --rm -tiv $(pwd)/runtime:/esis/runtime --env-file env-vars-template ghcr.io/kyc-esis-tech-challenge/automation-build:main load-data`

  - Projected data ingestion time to the Aurora PostgreSQL destination db is ~20 min
<br><br>
>Log into the pharmacy web app 
- See “Instructions on how to access the Production Solution and other tools”
- Execute use cases 14 and 15 (from the code submission document) in the web app 
<br><br>
>Execute the environment teardown script  (100% automated)
- Run the following docker command from a terminal  
  - `docker run --rm -tiv $(pwd)/runtime:/esis/runtime --env-file env-vars-template ghcr.io/kyc-esis-tech-challenge/automation-build:main destroy`

</details>
  
<details>
  <summary>Option 3: Windows deployment and execution steps for Evaluators</summary>
  
> Steps to configure your local machine to execute the single 100% automated infrastructure environment launch script
- Install Docker Desktop on your local machine. For instructions on how to do this see this link <https://docs.docker.com/get-started/>
- Start Docker Desktop
- Clone this `automation-runtime` repository to the C:\ directory
- Open a powershell window and CD to the cloned `automation-runtime` directory 
- Update the environment variable configuration file `env-vars-template` in the cloned local directory 
  - Update lines 1 and 2 with the AWS account access key and secret access key from the email sent to ESIS-EVAL@uscis.dhs.gov 
  - Update lines 3 and 4 with the Github credentials (username: esis-uscis-evaluator, personal access token in email) from the email sent to ESIS-EVAL@uscis.gov 
- Log into the GitHub container registry using the `esis-uscis-evaluator` user to pull down the executable docker image which will run the infrastructure environment launch script, teardown script and data processing pipeline. You can find the GitHub password (personal access token) for the `esis-uscis-evaluator` user in the email sent to ESIS-EVAL@uscis.dhs.gov 
  - In your powershell window and type in:
      - `docker login ghcr.io --username esis-uscis-evaluator --password <GitHub personal access token>`
<br><br>
>Execute the environment launch setup script (100% automated)
- Run the following docker command from your powershell window to deploy the entire infrastructure to AWS.  The first time you run this will pull down the executable docker image for running the scripts.  The docker image size is ~1.5GB  
  - `docker run --rm -tiv C:/runtime:/esis/runtime --env-file env-vars-template ghcr.io/kyc-esis-tech-challenge/automation-build:main create `
<br><br>
>Execute the data processing pipeline to ingest data to kafka  (100% automated)
- Run the following docker command from your powershell window  
  - `docker run --rm -tiv $(pwd)/runtime:/esis/runtime --env-file env-vars-template ghcr.io/kyc-esis-tech-challenge/automation-build:main load-data`
  - Projected data ingestion time to the Aurora PostgreSQL destination db is ~20 min
<br><br>
>Log into the pharmacy web app 
- See “Instructions on how to access the Production Solution and other tools”
- Execute use cases 14 and 15 (from the code submission document) in the web app 
<br><br>
>Execute the environment teardown script  (100% automated)
- Run the following docker command from your powershell window 
  - `docker run --rm -tiv C:/runtime:/esis/runtime --env-file env-vars-template ghcr.io/kyc-esis-tech-challenge/automation-build:main destroy`

</details>


# Instructions on how to access the Production Solution and other tools 
>After the create script has run you will see the output of the following URLs: 
- Production Web app: see above
- SonarQube: see above 
- Jenkins: see above
<br><br>
>Access to Jira and Confluence URLs instruction: 
- Log into myapps 
  - Go to <https://myapps.microsoft.com/> 
  - Enter your CVP Microsoft Username esis@cvpcorp.com and password (see email sent to ESIS-EVAL@uscis.dhs.gov) 
  - Click Sign On 
- Browse to the urls below: 
  - Jira URL: <https://jira.cvpcorp.com/projects/ESISTC/summary>
    - Exported list of User stories in GitHub: <https://github.com/kyc-esis-tech-challenge/automation-build/blob/main/UserStories.PDF>  
  - Confluence site URL: <https://beacon.cvpcorp.com/display/DETC/DHS-USCIS+ESIS+Tech+Challenge>    
    - Exported backup in GitHub: <https://github.com/kyc-esis-tech-challenge/documents/tree/main/confluence-export> 
<br><br>
>Access to AWS,and Google Voice 
- AWS console: see email sent to ESIS-EVAL@uscis.dhs.gov 
- Google Voice SMS: to see CloudWatch notification alerts (Req #5) login to google voice, see email sent to ESIS-EVAL@uscis.dhs.gov for Google login credentials
<br><br>
>Access to UCD artifacts
- [InvisionApp](<https://customervaluepartners.invisionapp.com/freehand/ESIS-TC-ZqQapVPar?dsid_h=3b78dab2bfd7b663eeb1fe1d859bb04fb23d7c06768e5f7b9e9ab71aaed92abd&uid_h=39690746c9233d259478fd9d020df4dc3d6398f768c92f1df5d68b3846ca49e0>)
- [HiFi mock up 1](https://xd.adobe.com/view/c28b0edb-99e8-41a0-a9ed-fd8129f71721-97d8/)
- [HiFi mock up 2](https://xd.adobe.com/view/86bf8cfb-d74c-4f95-b50f-222a66203440-d3ec/)


# Repository Hierarchy list 
The GitHub repository urls are here: <https://github.com/orgs/kyc-esis-tech-challenge/repositories>
<br><br>
![ESIS repo list](https://user-images.githubusercontent.com/66387533/192346411-c872e2d4-ce1c-4749-b7db-17386124c187.png)


# Document file breakdown
![ESIS document list](https://user-images.githubusercontent.com/66387533/192346459-f6565772-f846-4cae-b393-5607b18d4a14.png)
