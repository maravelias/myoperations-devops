#!/bin/bash

# Wait for SonarQube to be ready
echo "Waiting for SonarQube to start..."
until curl -s -u admin:admin http://sonarqube:9000/api/system/status | grep -q '"status":"UP"'; do
  sleep 5
done

echo "SonarQube is up. Creating predefined projects..."

# Function to create a project if it doesn't exist
create_project() {
  local name=$1
  local key=$2
  
  echo "Checking if project $key exists..."
  RESPONSE=$(curl -s -u admin:admin "http://sonarqube:9000/api/projects/search?projects=$key")
  
  if echo "$RESPONSE" | grep -q "\"key\":\"$key\""; then
    echo "Project $key already exists."
  else
    echo "Creating project $name ($key)..."
    curl -s -u admin:admin -X POST "http://sonarqube:9000/api/projects/create?name=$name&project=$key"
  fi
}

# Add your projects here
create_project "MyOperations" "myoperations"

echo "Initialization complete."
