# Disaster Recovery Runbook

This runbook provides step-by-step procedures for disaster recovery scenarios in the Multi-Region DR Platform.

## 🚨 Emergency Procedures

### Primary Region Complete Failure

**Scenario**: Primary region (us-east-1) is completely unavailable

**Detection**:
- Route 53 health checks failing
- Application not responding
- AWS console shows region issues

**Response Steps**:

1. **Verify the Outage** (2 minutes)
   ```bash
   # Check Route 53 health status
   aws route53 get-health-check-status --health-check-id <PRIMARY_HEALTH_CHECK_ID>
   
   # Check application endpoint
   curl -I https://your-domain.com/health
   
   # Verify AWS region status
   curl -s https://status.aws.amazon.com/ | grep "us-east-1"
   ```

2. **Assess Impact** (1 minute)
   - Verify secondary region is healthy
   - Check data replication status
   - Confirm backup systems are functioning

3. **Execute Failover** (2-5 minutes)
   ```bash
   # Option 1: Automated failover (if enabled)
   aws lambda invoke --function-name dr-platform-failover \
     --payload '{"failover_type":"full_failover","source_region":"us-east-1","target_region":"us-west-2"}' \
     response.json
   
   # Option 2: Manual DNS failover
   aws route53 change-resource-record-sets --hosted-zone-id <ZONE_ID> \
     --change-batch file://failover-changeset.json
   ```

4. **Verify Recovery** (2 minutes)
   ```bash
   # Test application availability
   curl -I https://your-domain.com/health
   
   # Check DNS propagation
   dig your-domain.com
   
   # Verify secondary region resources
   aws ecs describe-services --cluster dr-platform-cluster --region us-west-2
   ```

5. **Communicate** (1 minute)
   - Notify stakeholders
   - Update status page
   - Document actions taken

**Total RTO Target**: 5-10 minutes

### Database Failure

**Scenario**: Primary RDS database is unavailable but region is healthy

**Response Steps**:

1. **Verify Database Status**
   ```bash
   aws rds describe-db-instances --db-instance-identifier dr-platform-primary
   ```

2. **Promote Read Replica**
   ```bash
   aws rds promote-read-replica --db-instance-identifier dr-platform-replica --region us-west-2
   ```

3. **Update Application Configuration**
   - Update database endpoint in application
   - Restart application services
   - Verify connectivity

4. **Test Data Integrity**
   - Run data consistency checks
   - Verify recent transactions
   - Check application functionality

### S3 Data Corruption

**Scenario**: Primary S3 bucket data is corrupted or deleted

**Response Steps**:

1. **Assess Damage**
   ```bash
   aws s3 ls s3://dr-platform-primary-bucket --recursive | head -20
   aws s3 ls s3://dr-platform-secondary-bucket --recursive | head -20
   ```

2. **Restore from Secondary Region**
   ```bash
   # Sync from secondary to primary
   aws s3 sync s3://dr-platform-secondary-bucket s3://dr-platform-primary-bucket
   ```

3. **Verify Restoration**
   - Check file counts and sizes
   - Verify application can access data
   - Test critical application functions

## 🔧 Routine Procedures

### Monthly DR Test

**Frequency**: First Sunday of each month

**Procedure**:
1. Run automated DR test suite
   ```bash
   ./scripts/failover-test.sh all
   ```

2. Review test results and update documentation

3. Test manual failover procedures (in test environment)

4. Update recovery time estimates

5. Review and update contact information

### Quarterly DR Drill

**Frequency**: Once per quarter

**Procedure**:
1. Announce planned drill to all stakeholders
2. Execute full failover to secondary region
3. Run application tests in secondary region
4. Measure actual recovery times
5. Failback to primary region
6. Document lessons learned and improvements

### Weekly Health Checks

**Frequency**: Every Monday

**Procedure**:
1. Review Route 53 health check status
2. Check S3 replication metrics
3. Verify RDS replica lag
4. Review CloudWatch alarms
5. Check cost trends

## 📞 Emergency Contacts

### Internal Team
- **Primary Contact**: Platform Team Lead
- **Secondary Contact**: DevOps Engineer
- **Escalation**: Engineering Manager

### External Vendors
- **AWS Support**: [Your AWS Support Case URL]
- **DNS Provider**: [If using external DNS]
- **Monitoring Service**: [If using external monitoring]

## 📋 Pre-Failover Checklist

Before executing any failover:

- [ ] Verify the issue is actually a regional failure
- [ ] Check AWS Service Health Dashboard
- [ ] Confirm secondary region is healthy
- [ ] Verify data replication is up to date
- [ ] Notify key stakeholders
- [ ] Prepare rollback plan
- [ ] Document start time

## 📋 Post-Failover Checklist

After executing failover:

- [ ] Verify application functionality
- [ ] Check all integrations are working
- [ ] Monitor error rates and performance
- [ ] Update monitoring dashboards
- [ ] Communicate status to stakeholders
- [ ] Plan for eventual failback
- [ ] Document lessons learned

## 🔄 Failback Procedures

### When to Failback
- Primary region is fully operational
- All services have been restored
- Data synchronization is complete
- Minimal customer impact window is available

### Failback Steps
1. **Prepare Primary Region**
   - Ensure all services are healthy
   - Sync data from secondary to primary
   - Update configurations

2. **Schedule Maintenance Window**
   - Communicate planned maintenance
   - Prepare rollback procedures

3. **Execute Failback**
   - Scale up primary region resources
   - Update DNS records
   - Redirect traffic gradually

4. **Verify and Monitor**
   - Test all application functions
   - Monitor for 24 hours
   - Scale down secondary region

## 📊 Recovery Metrics

### Target Metrics
- **RTO (Recovery Time Objective)**: 5 minutes
- **RPO (Recovery Point Objective)**: 1 minute
- **Data Loss**: Zero for critical data
- **Service Availability**: 99.95% uptime

### Measurement
- Track actual recovery times
- Monitor data replication lag
- Measure customer impact
- Document improvement opportunities

## 🔍 Troubleshooting

### Common Issues

**DNS Propagation Delays**
- Some users may still hit primary region
- Wait for TTL expiration (60 seconds)
- Use Route 53 health check override if needed

**Application Database Connections**
- Applications may cache database connections
- Restart application services
- Check connection pool configurations

**S3 Cross-Region Replication Lag**
- Check replication metrics in CloudWatch
- Verify IAM permissions for replication
- Monitor for replication failures

**Route 53 Health Check False Positives**
- Verify health check configuration
- Check security groups and NACLs
- Review application health endpoint

## 📚 Additional Resources

- [AWS Disaster Recovery Best Practices](https://aws.amazon.com/disaster-recovery/)
- [Route 53 Health Checks Documentation](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/health-checks-types.html)
- [RDS Read Replica Documentation](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_ReadRepl.html)
- [S3 Cross-Region Replication](https://docs.aws.amazon.com/AmazonS3/latest/userguide/replication.html)

## 📝 Change Log

| Date | Change | Author |
|------|--------|--------|
| 2025-05-30 | Initial runbook creation | Platform Team |
| | | |

---

**Remember**: Practice makes perfect. Regular testing of these procedures ensures smooth execution during actual emergencies.
