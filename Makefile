.PHONY: all $(MAKECMDGOALS)

build:
	powershell docker build -t calculator-app .
	powershell docker build -t calc-web ./web

server:
	powershell docker run --rm --name apiserver --network-alias apiserver --env PYTHONPATH=/opt/calc --env FLASK_APP=app/api.py -p 5000:5000 -w /opt/calc calculator-app:latest flask run --host=0.0.0.0

test-unit:
	powershell docker run --name unit-tests --env PYTHONPATH=/opt/calc -w /opt/calc calculator-app:latest pytest --cov --cov-report=xml:results\coverage.xml --cov-report=html:results\coverage --junit-xml=results\unit_result.xml -m unit || true
	powershell docker cp unit-tests:/opt/calc/results ./
	powershell docker rm unit-tests || true

test-api:
	powershell docker network create calc-test-api || true
	powershell docker run -d --network calc-test-api --env PYTHONPATH=/opt/calc --name apiserver --env FLASK_APP=app/api.py -p 5000:5000 -w /opt/calc calculator-app:latest flask run --host=0.0.0.0
	powershell docker run --network calc-test-api --name api-tests --env PYTHONPATH=/opt/calc --env BASE_URL=http://apiserver:5000/ -w /opt/calc calculator-app:latest pytest --junit-xml=results\api_result.xml -m api || true
	powershell docker cp api-tests:/opt/calc/results ./
	powershell docker stop apiserver || true
	powershell docker rm --force apiserver || true
	powershell docker stop api-tests || true
	powershell docker rm --force api-tests || true
	powershell docker network rm calc-test-api || true

test-e2e:
	powershell docker network create calc-test-e2e || true
	powershell docker stop apiserver || true
	powershell docker rm --force apiserver || true
	powershell docker stop calc-web || true
	powershell docker rm --force calc-web || true
	powershell docker stop e2e-tests || true
	powershell docker rm --force e2e-tests || true
	powershell docker run -d --network calc-test-e2e --env PYTHONPATH=/opt/calc --name apiserver --env FLASK_APP=app/api.py -p 5000:5000 -w /opt/calc calculator-app:latest flask run --host=0.0.0.0
	powershell docker run -d --network calc-test-e2e --name calc-web -p 80:80 calc-web
	powershell docker create --network calc-test-e2e --name e2e-tests cypress/included:4.9.0 --browser chrome || true
	powershell docker cp .\test\e2e\cypress.json e2e-tests:/cypress.json
	powershell docker cp .\test\e2e\cypress e2e-tests:/cypress
	powershell docker start -a e2e-tests || true
	powershell docker cp e2e-tests:/results ./ || true
	powershell docker rm --force apiserver || true
	powershell docker rm --force calc-web || true
	powershell docker rm --force e2e-tests || true
	powershell docker network rm calc-test-e2e || true

run-web:
	powershell docker run --rm --volume "$(PWD)\web:/usr/share/nginx/html" --volume "$(PWD)\web\constants.local.js:/usr/share/nginx/html/constants.js" --name calc-web -p 80:80 nginx

stop-web:
	powershell docker stop calc-web

start-sonar-server:
	powershell docker network create calc-sonar || true
	powershell docker run -d --rm --stop-timeout 60 --network calc-sonar --name sonarqube-server -p 9000:9000 --volume "$(PWD)\sonar\data:/opt/sonarqube/data" --volume "$(PWD)\sonar\logs:/opt/sonarqube/logs" sonarqube:8.3.1-community

stop-sonar-server:
	powershell docker stop sonarqube-server
	powershell docker network rm calc-sonar || true

start-sonar-scanner:
	powershell docker run --rm --network calc-sonar -v "$(PWD):/usr/src" sonarsource/sonar-scanner-cli

pylint:
	powershell docker run --rm --volume "$(PWD):/opt/calc" --env PYTHONPATH=/opt/calc -w /opt/calc calculator-app:latest pylint app/ | tee results\pylint_result.txt

deploy-stage:
	powershell docker stop apiserver || true
	powershell docker stop calc-web || true
	powershell docker run -d --rm --name apiserver --network-alias apiserver --env PYTHONPATH=/opt/calc --env FLASK_APP=app/api.py -p 5000:5000 -w /opt/calc calculator-app:latest flask run --host=0.0.0.0
	powershell docker run -d --rm --name calc-web -p 80:80 calc-web
