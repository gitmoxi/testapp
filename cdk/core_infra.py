from aws_cdk import core
from aws_cdk import aws_ecs as ecs
from aws_cdk import aws_ec2 as ec2
from aws_cdk import aws_iam as iam
from aws_cdk import aws_logs as logs
import json

class MyEcsStack(core.Stack):

    def __init__(self, scope: core.Construct, id: str, cluster_name: str, vpc_cidr: str, app_port: int, role_name: str, log_group_name: str, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        # Create a VPC
        vpc = ec2.Vpc(self, "MyVpc",
                      cidr=vpc_cidr,
                      max_azs=3,
                      subnet_configuration=[
                          ec2.SubnetConfiguration(name="PublicSubnet", subnet_type=ec2.SubnetType.PUBLIC, cidr_mask=24),
                          ec2.SubnetConfiguration(name="PrivateSubnet", subnet_type=ec2.SubnetType.PRIVATE, cidr_mask=24)
                      ])

        # Create an ECS cluster
        cluster = ecs.Cluster(self, "MyCluster",
                              cluster_name=cluster_name,
                              vpc=vpc)

        # Create a security group
        security_group = ec2.SecurityGroup(self, "MySecurityGroup",
                                           vpc=vpc,
                                           allow_all_outbound=True)
        security_group.add_ingress_rule(ec2.Peer.any_ipv4(), ec2.Port.tcp(app_port), "Allow inbound on app port")

        # Create a task execution role
        task_execution_role = iam.Role(self, "MyTaskExecutionRole",
                                       assumed_by=iam.ServicePrincipal("ecs-tasks.amazonaws.com"),
                                       role_name=role_name)
        task_execution_role.add_managed_policy(iam.ManagedPolicy.from_aws_managed_policy_name("service-role/AmazonECSTaskExecutionRolePolicy"))

        # Output the CloudWatch log group name
        # Create a CloudWatch log group and assign it to a variable
        log_group = logs.LogGroup(self, "MyLogGroup",
                                  log_group_name=log_group_name)
        # Output the ECS cluster name
        core.CfnOutput(self, "ClusterNameOutput", value=cluster.cluster_name, description="The name of the ECS cluster")

        # Output the IDs of the public subnets
        public_subnets = vpc.select_subnets(subnet_type=ec2.SubnetType.PUBLIC)
        public_subnet_ids = [subnet.subnet_id for subnet in public_subnets.subnets]
        core.CfnOutput(self, "PublicSubnetIdsOutput", value=json.dumps(public_subnet_ids), description="The IDs of the public subnets")

        # Output the security group ID
        core.CfnOutput(self, "SecurityGroupIdOutput", value=json.dumps([security_group.security_group_id]), description="The ID of the security group")

        # Output the task execution role ARN
        core.CfnOutput(self, "TaskExecutionRoleArnOutput", value=task_execution_role.role_arn, description="The ARN of the task execution role")

        # Output the CloudWatch log group name using the variable
        core.CfnOutput(self, "LogGroupNameOutput", value=log_group.log_group_name, description="The name of the CloudWatch log group")

app = core.App()
MyEcsStack(app, "MyEcsStack",
           cluster_name="MyCluster",
           vpc_cidr="10.0.0.0/16",
           app_port=80,
           role_name="MyTaskExecutionRole",
           log_group_name="/ecs/my-cluster")

app.synth()