#!/bin/bash

#Script functions
map_images () {
        touch ${_OUTPUTFILES}/${_IMAGE}.csv
        echo "Tag,Created,batch,build-date,Z-Release" > ${_OUTPUTFILES}/${_IMAGE}.csv
        # Define a lock variable to parallelize skopeo execution
        _MAPLOCK=0
        # For the given image, inspect the latest tag to discover all the others tags then nicely format the `jq` output for the next step
        for _TAG in $(skopeo inspect docker://${_REGISTRY}/${_LIBRARY}/${_IMAGE}:latest | jq '.[ "RepoTags" ]' | tr -d '[],"' | sed -e '/^$/d' -e 's/ //g' -e '/^'${_OSPVERS}'$/d' | sort -n -k1.6 | grep -v source )
        do
                # Verification to execute a max of 6 concurrrent skopeo instances
                if (( ${_MAPLOCK} < 6 )); then
                        map_z_releases &
                        ((_MAPLOCK++))
                # When more than 6 are already running, wait here. This is a fake parallelization since it will wait until all previous threads are done
                elif (( ${_MAPLOCK} >= 6 )); then
                        wait
                        _MAPLOCK=0
                        map_z_releases &
                        ((_MAPLOCK++))
                fi
        done
        # Wait for any remaining thread
        wait
        # The output file is not sorted (given that was written in different orders) Sort it by the first column (the TAG one)
        (head -n 1 ${_OUTPUTFILES}/${_IMAGE}.csv && tail -n +3 ${_OUTPUTFILES}/${_IMAGE}.csv | sort -n -k1.6) > ${_OUTPUTFILES}/${_IMAGE}_sorted.csv
        mv -f ${_OUTPUTFILES}/${_IMAGE}_sorted.csv ${_OUTPUTFILES}/${_IMAGE}.csv
}

map_z_releases () {
        echo "## Processing ${_IMAGE}:${_TAG}"
        # Save `skopeo inspect` output in a variable
        _INSPECTED=$(skopeo inspect docker://${_REGISTRY}/${_LIBRARY}/${_IMAGE}:${_TAG})
        # Extract the Created value
        _CREATED=$(echo "${_INSPECTED}" | jq '.[ "Created" ]' | sed -e 's/"//g')
        # Extract the batch value under Labels
        _BATCH=$(echo "${_INSPECTED}" | jq '.[ "Labels" ]' | jq '.[ "batch" ]' | sed -e 's/"//g')
        # Extract the build-date value under Labels
        _BUILDDATE=$(echo "${_INSPECTED}" | jq '.[ "Labels" ]' | jq '.[ "build-date" ]' | sed -e 's/"//g')

        # Now it's time to map the Created value with a Z-Release
        # The following assumptions are made:
        # - If the image was created more than 7 days earlier it's the previous release
        # - If the image was created within (+ and -) 7 days it's the current release

        # Older than 7 days, this was a Beta container
        if (( $(date -d "${_CREATED}" +%s) < $(date -d "${_GADATE}-7 days" +%s) )); then
                _ZRELEASE=Beta
        # if the image creation date is not less than 7 days from the official Z-Release and not more than 7 days from it, it's the current Z-Release
        elif (( $(date -d "${_CREATED}" +%s) >= $(date -d "${_GADATE}-7 days" +%s) && $(date -d "${_CREATED}" +%s) <= $(date -d "${_GADATE}+7 days" +%s) )); then
                _ZRELEASE=GA
        # if the image creation date is more than 7 days after the official Z-Release and is also less than 7 days from the next one, it's an async release
        elif (( $(date -d "${_CREATED}" +%s) > $(date -d "${_GADATE}+7 days" +%s) && $(date -d "${_CREATED}" +%s) < $(date -d "${_Z1DATE}-7 days" +%s) )); then
                _ZRELEASE=GA.async
        elif (( $(date -d "${_CREATED}" +%s) >= $(date -d "${_Z1DATE}-7 days" +%s) && $(date -d "${_CREATED}" +%s) <= $(date -d "${_Z1DATE}+7 days" +%s) )); then
                _ZRELEASE=Z1
        elif (( $(date -d "${_CREATED}" +%s) > $(date -d "${_Z1DATE}+7 days" +%s) && $(date -d "${_CREATED}" +%s) < $(date -d "${_Z2DATE}-7 days" +%s) )); then
                _ZRELEASE=Z1.async
        elif (( $(date -d "${_CREATED}" +%s) >= $(date -d "${_Z2DATE}-7 days" +%s) && $(date -d "${_CREATED}" +%s) <= $(date -d "${_Z2DATE}+7 days" +%s) )); then
                _ZRELEASE=Z2
        elif (( $(date -d "${_CREATED}" +%s) > $(date -d "${_Z2DATE}+7 days" +%s) && $(date -d "${_CREATED}" +%s) < $(date -d "${_Z3DATE}-7 days" +%s) )); then
                _ZRELEASE=Z2.async
        elif (( $(date -d "${_CREATED}" +%s) >= $(date -d "${_Z3DATE}-7 days" +%s) && $(date -d "${_CREATED}" +%s) <= $(date -d "${_Z3DATE}+7 days" +%s) )); then
                _ZRELEASE=Z3
        elif (( $(date -d "${_CREATED}" +%s) > $(date -d "${_Z3DATE}+7 days" +%s) && $(date -d "${_CREATED}" +%s) < $(date -d "${_Z4DATE}-7 days" +%s) )); then
                _ZRELEASE=Z3.async
        elif (( $(date -d "${_CREATED}" +%s) >= $(date -d "${_Z4DATE}-7 days" +%s) && $(date -d "${_CREATED}" +%s) <= $(date -d "${_Z4DATE}+7 days" +%s) )); then
                _ZRELEASE=Z4
        elif (( $(date -d "${_CREATED}" +%s) > $(date -d "${_Z4DATE}+7 days" +%s) && $(date -d "${_CREATED}" +%s) < $(date -d "${_Z5DATE}-7 days" +%s) )); then
                _ZRELEASE=Z4.async
        elif (( $(date -d "${_CREATED}" +%s) >= $(date -d "${_Z5DATE}-7 days" +%s) && $(date -d "${_CREATED}" +%s) <= $(date -d "${_Z5DATE}+7 days" +%s) )); then
                _ZRELEASE=Z5
        elif (( $(date -d "${_CREATED}" +%s) > $(date -d "${_Z5DATE}+7 days" +%s) && $(date -d "${_CREATED}" +%s) < $(date -d "${_Z6DATE}-7 days" +%s) )); then
                _ZRELEASE=Z5.async
        elif (( $(date -d "${_CREATED}" +%s) >= $(date -d "${_Z6DATE}-7 days" +%s) && $(date -d "${_CREATED}" +%s) <= $(date -d "${_Z6DATE}+7 days" +%s) )); then
                _ZRELEASE=Z6
        elif (( $(date -d "${_CREATED}" +%s) > $(date -d "${_Z6DATE}+7 days" +%s) && $(date -d "${_CREATED}" +%s) < $(date -d "${_Z7DATE}-7 days" +%s) )); then
                _ZRELEASE=Z6.async
        elif (( $(date -d "${_CREATED}" +%s) >= $(date -d "${_Z7DATE}-7 days" +%s) && $(date -d "${_CREATED}" +%s) <= $(date -d "${_Z7DATE}+7 days" +%s) )); then
                _ZRELEASE=Z7
        elif (( $(date -d "${_CREATED}" +%s) > $(date -d "${_Z7DATE}+7 days" +%s) && $(date -d "${_CREATED}" +%s) < $(date -d "${_Z8DATE}-7 days" +%s) )); then
                _ZRELEASE=Z7.async
        elif (( $(date -d "${_CREATED}" +%s) >= $(date -d "${_Z8DATE}-7 days" +%s) && $(date -d "${_CREATED}" +%s) <= $(date -d "${_Z8DATE}+7 days" +%s) )); then
                _ZRELEASE=Z8
        elif (( $(date -d "${_CREATED}" +%s) > $(date -d "${_Z8DATE}+7 days" +%s) && $(date -d "${_CREATED}" +%s) < $(date -d "${_Z9DATE}-7 days" +%s) )); then
                _ZRELEASE=Z8.async
        elif (( $(date -d "${_CREATED}" +%s) >= $(date -d "${_Z9DATE}-7 days" +%s) && $(date -d "${_CREATED}" +%s) <= $(date -d "${_Z9DATE}+7 days" +%s) )); then
                _ZRELEASE=Z9
        elif (( $(date -d "${_CREATED}" +%s) > $(date -d "${_Z9DATE}+7 days" +%s) && $(date -d "${_CREATED}" +%s) < $(date -d "${_Z10DATE}-7 days" +%s) )); then
                _ZRELEASE=Z9.async
        elif (( $(date -d "${_CREATED}" +%s) >= $(date -d "${_Z10DATE}-7 days" +%s) && $(date -d "${_CREATED}" +%s) <= $(date -d "${_Z10DATE}+7 days" +%s) )); then
                _ZRELEASE=Z10
        elif (( $(date -d "${_CREATED}" +%s) > $(date -d "${_Z10DATE}+7 days" +%s) && $(date -d "${_CREATED}" +%s) < $(date -d "${_Z11DATE}-7 days" +%s) )); then
                _ZRELEASE=Z10.async
        elif (( $(date -d "${_CREATED}" +%s) >= $(date -d "${_Z11DATE}-7 days" +%s) && $(date -d "${_CREATED}" +%s) <= $(date -d "${_Z11DATE}+7 days" +%s) )); then
                _ZRELEASE=Z11
        elif (( $(date -d "${_CREATED}" +%s) > $(date -d "${_Z11DATE}+7 days" +%s) && $(date -d "${_CREATED}" +%s) < $(date -d "${_Z12DATE}-7 days" +%s) )); then
                _ZRELEASE=Z11.async
        elif (( $(date -d "${_CREATED}" +%s) >= $(date -d "${_Z12DATE}-7 days" +%s) && $(date -d "${_CREATED}" +%s) <= $(date -d "${_Z12DATE}+7 days" +%s) )); then
                _ZRELEASE=Z12
        elif (( $(date -d "${_CREATED}" +%s) > $(date -d "${_Z12DATE}+7 days" +%s) && $(date -d "${_CREATED}" +%s) < $(date -d "${_Z13DATE}-7 days" +%s) )); then
                _ZRELEASE=Z12.async
        elif (( $(date -d "${_CREATED}" +%s) >= $(date -d "${_Z13DATE}-7 days" +%s) && $(date -d "${_CREATED}" +%s) <= $(date -d "${_Z13DATE}+7 days" +%s) )); then
                _ZRELEASE=Z13
        elif (( $(date -d "${_CREATED}" +%s) > $(date -d "${_Z13DATE}+7 days" +%s) && $(date -d "${_CREATED}" +%s) < $(date -d "${_Z14DATE}-7 days" +%s) )); then
                _ZRELEASE=Z13.async
        elif (( $(date -d "${_CREATED}" +%s) >= $(date -d "${_Z14DATE}-7 days" +%s) && $(date -d "${_CREATED}" +%s) <= $(date -d "${_Z14DATE}+7 days" +%s) )); then
                _ZRELEASE=Z14
        elif (( $(date -d "${_CREATED}" +%s) > $(date -d "${_Z14DATE}+7 days" +%s) && $(date -d "${_CREATED}" +%s) < $(date -d "${_Z15DATE}-7 days" +%s) )); then
                _ZRELEASE=Z14.async
        elif (( $(date -d "${_CREATED}" +%s) >= $(date -d "${_Z15DATE}-7 days" +%s) && $(date -d "${_CREATED}" +%s) <= $(date -d "${_Z15DATE}+7 days" +%s) )); then
                _ZRELEASE=Z15
        elif (( $(date -d "${_CREATED}" +%s) > $(date -d "${_Z15DATE}+7 days" +%s) && $(date -d "${_CREATED}" +%s) < $(date -d "${_Z16DATE}-7 days" +%s) )); then
                _ZRELEASE=Z15.async
        elif (( $(date -d "${_CREATED}" +%s) >= $(date -d "${_Z16DATE}-7 days" +%s) && $(date -d "${_CREATED}" +%s) <= $(date -d "${_Z16DATE}+7 days" +%s) )); then
                _ZRELEASE=Z16
        elif (( $(date -d "${_CREATED}" +%s) > $(date -d "${_Z16DATE}+7 days" +%s) && $(date -d "${_CREATED}" +%s) < $(date -d "${_Z17DATE}-7 days" +%s) )); then
                _ZRELEASE=Z16.async

        fi
        # Output a CSV named after the Image Name including Image Tag, Create, Batch and Build-date tags and last Z-Release version
        echo "${_TAG},${_CREATED},${_BATCH},${_BUILDDATE},${_ZRELEASE}" >> ${_OUTPUTFILES}/${_IMAGE}.csv
}

# Define Docker Registry
_REGISTRY="registry.redhat.io"
# Test Image to verify Registry access credential
_TEST="rhel7"
# Registry Library where all the images are
_LIBRARY="rhosp13"
# OpenStack Platform Version (also part of the Tag)
_OSPVERS="13.0"

# Images to extracts the dates
_IMAGES="openstack-aodh-api openstack-aodh-evaluator openstack-aodh-listener openstack-aodh-notifier openstack-ceilometer-central openstack-ceilometer-compute openstack-ceilometer-notification openstack-cinder-api openstack-cinder-scheduler openstack-cinder-volume openstack-cron openstack-fluentd openstack-glance-api openstack-gnocchi-api openstack-gnocchi-metricd openstack-gnocchi-statsd openstack-haproxy openstack-heat-api-cfn openstack-heat-api openstack-heat-engine openstack-horizon openstack-iscsid openstack-keystone openstack-mariadb openstack-memcached openstack-neutron-dhcp-agent openstack-neutron-l3-agent openstack-neutron-metadata-agent openstack-neutron-openvswitch-agent openstack-neutron-sriov-agent openstack-neutron-server openstack-nova-api openstack-nova-compute openstack-nova-conductor openstack-nova-consoleauth openstack-nova-libvirt openstack-nova-novncproxy openstack-nova-placement-api openstack-nova-scheduler openstack-panko-api openstack-rabbitmq openstack-redis openstack-sensu-client openstack-swift-account openstack-swift-container openstack-swift-object openstack-swift-proxy-server"
# Outout Dir
_OUTPUTFILES="./"
# Release Dates, based on official release notes at https://access.redhat.com/documentation/en-us/red_hat_openstack_platform/13/html/release_notes/index
_GADATE="2018-06-27"
_Z1DATE="2018-07-19"
_Z2DATE="2018-08-29"
_Z3DATE="2018-11-13"
_Z4DATE="2019-01-16"
_Z5DATE="2019-03-13"
_Z6DATE="2019-04-30"
_Z7DATE="2019-07-10"
_Z8DATE="2019-09-04"
_Z9DATE="2019-11-06"
_Z10DATE="2019-12-19"
_Z11DATE="2020-03-10"
_Z12DATE="2020-06-24"
_Z13DATE="2020-07-01"
_Z14DATE="2020-12-16"
_Z15DATE="2021-03-17"
_Z16DATE="2021-06-16"
# Z16 is the end of support but need it for the if-conditions
# Z17 and above will be extended support
_Z17DATE="2021-08-03"

# Ensure Docker, skopeo, and JQ are installed
_REDHAT_RELEASE=$(cut -d: -f 5 /etc/system-release-cpe | cut -d . -f 1)
if [[ $_REDHAT_RELEASE -eq 7 ]]; then
  echo "OS RHEL7 detected..."
  rpm -q docker >/dev/null 2>&1 || sudo yum install -y docker
  rpm -q skopeo >/dev/null 2>&1 || sudo yum install -y skopeo
  rpm -q jq >/dev/null 2>&1 || sudo yum install -y jq
  _CONTAINER_BINARY="docker"
elif [[ $_REDHAT_RELEASE -eq 8 ]]; then
  echo "OS RHEL8 detected..."
  rpm -q podman >/dev/null 2>&1 || sudo dnf install -y podman
  rpm -q skopeo >/dev/null 2>&1 || sudo dnf install -y skopeo
  rpm -q jq >/dev/null 2>&1 || sudo dnf install -y jq
  _CONTAINER_BINARY="podman"
else 
  echo "OS not supported by this script.."
  exit 1
fi

# Verify Registry login credential
skopeo inspect docker://${_REGISTRY}/${_TEST}:latest >/dev/null 2>&1 || ${_CONTAINER_BINARY} login ${_REGISTRY}

# Define a lock variable to parallelize skopeo execution
_IMAGELOCK=0
# One Image by one
for _IMAGE in ${_IMAGES}
do
        # Verification to execute a max of 3 concurrrent images inspects
        if (( ${_IMAGELOCK} < 3 )); then
                map_images &
                ((_IMAGELOCK++))
        # When more than 3 are already running, wait here. This is a fake parallelization since it will wait until all previous threads are done
        elif (( ${_IMAGELOCK} >= 3 )); then
                wait
                _IMAGELOCK=0
                map_images &
                ((_IMAGELOCK++))
        fi
done

# Wait for any remaining thread
wait

exit 0
