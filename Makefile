ifdef CIRCLECI
	RUN := pipenv run
else ifdef HEROKU_APP_NAME
	SKIP_INSTALL := true
else
	RUN := pipenv run
endif

.PHONY: all
all: install

.PHONY: ci
ci: check test ## CI | Run all validation targets

.PHONY: watch
watch: install ## CI | Rerun all validation targests in a loop
	@ rm -rf $(FAILURES)
	$(RUN) sniffer

# SYSTEM DEPENDENCIES #########################################################

.PHONY: doctor
doctor: ## Check for required system dependencies
	bin/verchew

# PROJECT DEPENDENCIES ########################################################

export PIPENV_VENV_IN_PROJECT=true
VENV := .venv

BACKEND_DEPENDENCIES := $(VENV)/.pipenv-$(shell bin/checksum Pipfile*)
FRONTEND_DEPENDENCIES :=

.PHONY: install
ifndef SKIP_INSTALL
install: $(BACKEND_DEPENDENCIES) $(FRONTEND_DEPENDENCIES) ## Install project dependencies
endif

$(BACKEND_DEPENDENCIES):
	@ rm -rf $(VENV)/.pipenv-*
	pipenv install --dev
	@ touch $@

$(FRONTEND_DEPENDENCIES):
	# TODO: Install frontend dependencies if applicable
	@ touch $@

.PHONY: clean
clean:
	rm -rf staticfiles
	rm -rf .coverage htmlcov

.PHONY: clean-all
clean-all: clean
	# TODO: Delete all frontend files
	rm -rf $(VENV)

# RUNTIME DEPENDENCIES ########################################################

.PHONY: migrations
migrations: install  ## Database | Generate database migrations
	# TODO: Generate migrations

.PHONY: migrate
migrate: install ## Database | Run database migrations
	# TODO: Run migrations

.PHONY: data
data: install migrate ## Database | Seed data for manual testing
	# TODO: Load test data and fixtures

.PHONY: reset
reset: install ## Database | Create a new database, migrate, and seed it
	- dropdb demo_project_dev
	- createdb demo_project_dev
	make data

# VALIDATION TARGETS ##########################################################

PYTHON_PACKAGES := demo_project
FAILURES := .pytest_cache/v/cache/lastfailed

.PHONY: check
check: check-backend ## Run static analysis

.PHONY: check-backend
check-backend: install
	$(RUN) pylint $(PYTHON_PACKAGES) tests --rcfile=.pylint.ini
	$(RUN) pycodestyle $(PYTHON_PACKAGES) tests --config=.pycodestyle.ini

.PHONY: check-frontend
check-frontend: install
	# TODO: Run frontend linters if applicable

.PHONY: test
test: test-backend test-frontend ## Run all tests

.PHONY: test-backend
test-backend: test-backend-all

.PHONY: test-backend-unit
test-backend-unit: install
	@ ( mv $(FAILURES) $(FAILURES).bak || true ) > /dev/null 2>&1
	$(RUN) pytest $(PYTHON_PACKAGES) tests/unit
	@ ( mv $(FAILURES).bak $(FAILURES) || true ) > /dev/null 2>&1
	$(RUN) coveragespace update unit

.PHONY: test-backend-integration
test-backend-integration: install
	@ if test -e $(FAILURES); then $(RUN) pytest tests/integration; fi
	@ rm -rf $(FAILURES)
	$(RUN) pytest tests/integration
	$(RUN) coveragespace update integration

.PHONY: test-backend-all
test-backend-all: install
	@ if test -e $(FAILURES); then $(RUN) pytest $(PYTHON_PACKAGES) tests/integration; fi
	@ rm -rf $(FAILURES)
	$(RUN) pytest $(PYTHON_PACKAGES) tests/integration
	$(RUN) coveragespace update overall

.PHONY: test-frontend
test-frontend: test-frontend-unit

.PHONY: test-frontend-unit
test-frontend-unit: install
	# TODO: Run frontend tests if applicable

.PHONY: test-system
test-system: install
	$(RUN) honcho start --procfile=tests/system/Procfile --env=tests/system/.env

# SERVER TARGETS ##############################################################

export FLASK_APP=demo_project/app.py

.PHONY: run
run: install ## Run the applicaiton
	FLASK_ENV=local $(RUN) python manage.py runserver

.PHONY: run-production
run-production: install ## Run the application (simulate production)
	pipenv shell "bin/pre_compile; exit \$$?"
	pipenv shell "bin/post_compile; exit \$$?"
	pipenv shell "heroku local release; exit \$$?"
	pipenv shell "FLASK_ENV=production heroku local web; exit \$$?"

# RELEASE TARGETS #############################################################

.PHONY: build
build: install
	# TODO: Build frontend code for production if applicable

.PHONY: promote
promote: install
	TEST_SITE=https://staging.demo_project.com $(RUN) pytest tests/system --cache-clear
	heroku pipelines:promote --app demo_project-staging --to demo_project
	TEST_SITE=https://demo_project.com $(RUN) pytest tests/system

# HELP ########################################################################

.PHONY: help
help: all
	@ grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
