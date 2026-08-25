script_arg <- grep("^--file=", commandArgs(), value = TRUE)
root <- normalizePath(file.path(dirname(normalizePath(sub("^--file=", "", script_arg[1]))), ".."))
source(file.path(root, "environment", "check_author_environment.R"))
assert_author_environment(root, write_outputs = FALSE)
output_dir <- Sys.getenv("THESIS_VALIDATION_OUTPUT_DIR", unset = file.path(root, "validation"))
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
source(file.path(root, "config", "extension_config.R"))
for (f in c("dgp_kappa.R", "author_oracle_wrapper.R", "author_full_wrapper.R", "author_bc_dml_wrapper.R")) source(file.path(root, "src", f))

reference_gmm_candidate <- function(y,D,X,Z,tau,a) {
  beta <- quantreg::rq(y-(a*D) ~ X, tau=tau)
  beta <- matrix(beta$coefficients,nrow=1)
  e <- y-a*D-cbind(1,X)%*%t(beta)
  distribition <- diag(c(dnorm(e,mean(e),var(e))))
  M <- t(Z)%*%distribition%*%X; J <- t(X)%*%distribition%*%X
  delta <- M%*%solve(J); psi <- t(Z)-delta%*%t(X)
  indicator <- ifelse(e<=0,1,0); g <- psi%*%(tau-indicator)
  invsigma <- solve(psi%*%diag(diag((tau-indicator)%*%t(tau-indicator)))%*%t(psi))
  drop(t(g)%*%invsigma%*%g)
}

reference_bc_candidate <- function(y,D,X,Z,tau,a) {
  norm2n <- function(z) sqrt(mean(z^2))
  lambda.BC <- function(X,R=1000,tau=.5,c=2,alpha=.1) {
    n <- nrow(X); sigs <- apply(X,2,norm2n); U <- matrix(runif(n*R),n)
    R <- (t(X)%*%(tau-(U<tau)))/(sigs*sqrt(tau*(1-tau))); r <- apply(abs(R),2,max)
    c*quantile(r,1-alpha)*sqrt(tau*(1-tau))*c(1,sigs)
  }
  lambda <- lambda.BC(X,tau=tau,c=2,alpha=.1)
  lasso <- quantreg::rq(y-a*D ~ X,tau=tau,method="lasso",lambda=lambda)
  beta <- matrix(lasso$coefficients,ncol=1); e <- y-a*D-cbind(1,X)%*%beta
  distribition <- sqrt(diag(c(dnorm(e,mean(e),var(e)))))
  psi <- matrix(0,nrow=length(Z[1,]),ncol=length(Z[,1]))
  for(j in 1:length(Z[1,])) {
    delta <- hdm::rlasso(distribition%*%Z[,j] ~ distribition%*%X,post=FALSE)
    delta <- matrix(delta$coefficients,ncol=1); delta <- Z[,j]-cbind(1,X)%*%delta; psi[j,] <- t(delta)
  }
  indicator <- ifelse(e<=0,1,0); g <- psi%*%(tau-indicator)
  invsigma <- solve(psi%*%diag(diag((tau-indicator)%*%t(tau-indicator)))%*%t(psi))
  list(lambda=lambda,beta=beta,W=drop(t(g)%*%invsigma%*%g))
}

set.seed(19231); dat <- make_kappa_dataset(generate_kappa_primitives(500L),1); tau <- .5
oracle_ref <- vapply(extension_config$alpha_grid, function(a) reference_gmm_candidate(dat$y,dat$D,dat$X1,dat$Z,tau,a), numeric(1))
oracle_ext <- author_oracle_profile(dat$y,dat$D,dat$X1,dat$Z,tau,extension_config$alpha_grid)$W
full_ref <- vapply(extension_config$alpha_grid, function(a) reference_gmm_candidate(dat$y,dat$D,dat$X,dat$Z,tau,a), numeric(1))
full_ext <- author_full_profile(dat$y,dat$D,dat$X,dat$Z,tau,extension_config$alpha_grid)$W

rows <- lapply(c(-1,1,3), function(a) {
  set.seed(44000 + round(10*a)); ref <- reference_bc_candidate(dat$y,dat$D,dat$X,dat$Z,tau,a)
  set.seed(44000 + round(10*a)); ext <- author_bc_candidate(dat$y,dat$D,dat$X,dat$Z,tau,a,TRUE)
  data.frame(a=a,lambda_max_diff=max(abs(ref$lambda-ext$lambda)),beta_max_diff=max(abs(ref$beta-ext$beta)),W_abs_diff=abs(ref$W-ext$W))
})
dml <- do.call(rbind,rows)
summary <- data.frame(test=c("Oracle W profile","Full W profile"), max_abs_diff=c(max(abs(oracle_ref-oracle_ext)),max(abs(full_ref-full_ext))))
stopifnot(all(summary$max_abs_diff <= 1e-12), all(dml[, -1] <= 1e-12))
write.csv(summary,file.path(output_dir,"author_gmm_equivalence.csv"),row.names=FALSE)
write.csv(dml,file.path(output_dir,"author_bc_candidate_equivalence.csv"),row.names=FALSE)
print(summary); print(dml)
