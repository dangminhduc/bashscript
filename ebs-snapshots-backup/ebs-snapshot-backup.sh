#!/bin/bash
###
### EBS Snapshot shell
###
### @see http://dev.classmethod.jp/cloud/aws/aws-cfn-advent-calendar-2013-snapshot/
###
### 上記サイトを参考に修正したEBSのスナップショットシェル
### TagにBackup=trueのものを自動的にバックアップする
###

### SETTING
export AWS_ACCESS_KEY_ID=
export AWS_SECRET_ACCESS_KEY=
export AWS_DEFAULT_REGION=

WORKDIR=/tmp
DATE_CURRENT=$(date +'%Y-%m-%d')
CMD_DIR=/usr/bin


### FUNCTIONS

get_purge_after_date()
{
  case `uname` in
      Linux) echo `date -d +${PURGE_AFTER_DAYS}days -u +%Y-%m-%d` ;;
          Darwin) echo `date -v+${PURGE_AFTER_DAYS}d -u +%Y-%m-%d` ;;
	      *) echo `date -d +${PURGE_AFTER_DAYS}days -u +%Y-%m-%d` ;;
	        esac
		}

		get_purge_after_date_epoch()
		{
		  case `uname` in
		      Linux) echo `date -d $PURGE_AFTER_DATE +%s` ;;
		          Darwin) echo `date -j -f "%Y-%m-%d" $PURGE_AFTER_DATE "+%s"` ;;
			      *) echo `date -d $PURGE_AFTER_DATE +%s` ;;
			        esac
				}

				get_date_current_epoch()
				{
				  case `uname` in
				      Linux) echo `date -d $DATE_CURRENT +%s` ;;
				          Darwin) echo `date -j -f "%Y-%m-%d" $DATE_CURRENT "+%s"` ;;
					      *) echo `date -d $DATE_CURRENT +%s` ;;
					        esac
						}


						### MAIN

						if [[ $# < 1 ]]; then
						    echo "$0 <purge_after_days>";
						        exit;
							fi

							# 何日間のスナップショットを取るか
							PURGE_AFTER_DAYS=$1

							PURGEAFTER=`get_purge_after_date`

							# バックアップ取得
							$CMD_DIR/aws ec2 describe-volumes > $WORKDIR/describe-volumes.json
							VOLUMES=$(cat $WORKDIR/describe-volumes.json | jq -r '.Volumes[].VolumeId')

							for VOL in $VOLUMES; do
							  echo "checking backup flag of volume [$VOL]"
							    BACKUP=$($CMD_DIR/aws ec2 describe-tags \
							               --filters "Name=resource-type,Values=volume" \
								                            "Name=resource-id,Values=$VOL" \
											                         "Name=key,Values=Backup" \
														            --query "Tags[*].Value" --output text \
															               --no-paginate )
																         if [ "$BACKUP" == "true" ]; then
																	     INSTANCE_ID=$(cat $WORKDIR/describe-volumes.json | jq -r '.Volumes[] | select(.VolumeId == "'$VOL'") | .Attachments[].InstanceId')
																	         echo "backup volume [$VOL] attached to ${INSTANCE_ID}"
																		     $CMD_DIR/aws ec2 create-snapshot --volume-id $VOL --description "auto:${VOL}_${DATE_CURRENT}(${INSTANCE_ID})" > $WORKDIR/create-snapshot-result.json
																		         SNAPSHOT_ID=$(cat $WORKDIR/create-snapshot-result.json | jq -r ".SnapshotId")
																			     $CMD_DIR/aws ec2 create-tags --resources $SNAPSHOT_ID --tags Key=PurgeAllow,Value=true > $WORKDIR/create-tags-purgeallow.json
																			         $CMD_DIR/aws ec2 create-tags --resources $SNAPSHOT_ID --tags Key=PurgeAfter,Value=$PURGEAFTER > $WORKDIR/create-tags-purgeafter.json
																				   fi
																				   done

																				   # バックアップ削除
																				   $CMD_DIR/aws ec2 describe-tags --filters "Name=resource-type,Values=snapshot" "Name=key,Values=PurgeAllow,PurgeAfter" > $WORKDIR/describe-tags.json
																				   SNAPSHOT_PURGE_ALLOWED=$(cat $WORKDIR/describe-tags.json | jq -r '.Tags[] | select(.Key == "PurgeAllow" and .Value == "true") | .ResourceId')
																				   for SNAPSHOT_ID in $SNAPSHOT_PURGE_ALLOWED; do
																				     PURGE_AFTER_DATE=$(cat $WORKDIR/describe-tags.json | jq -r '.Tags[]
																				                          | select(.ResourceId == "'$SNAPSHOT_ID'" and .Key == "PurgeAfter")
																							                       | .Value')
																									         echo "checking snapshot PurgeAfter date is before current [${SNAPSHOT_ID} / ${PURGE_AFTER_DATE}]"
																										   if [ -n $PURGE_AFTER_DATE ]; then
																										       DATE_CURRENT_EPOCH=`get_date_current_epoch`
																										           PURGE_AFTER_DATE_EPOCH=`get_purge_after_date_epoch`
																											       if [[ $PURGE_AFTER_DATE_EPOCH < $DATE_CURRENT_EPOCH ]]; then
																											             echo "The snapshot ${SNAPSHOT_ID} with the Purge After date of $PURGE_AFTER_DATE will be deleted."
																												           $CMD_DIR/aws ec2 delete-snapshot --snapshot-id $SNAPSHOT_ID
																													       fi
																													         fi
																														 done
